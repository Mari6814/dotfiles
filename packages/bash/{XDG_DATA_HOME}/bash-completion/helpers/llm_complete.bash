# LLM-backed Bash completion.
#
#   source /path/to/llm_complete        # only defines functions
#
#   complete -o bashdefault -o default -F _llm_complete mycmd
#
# Nothing is registered by default: enable each command with its own
# `complete -F`. `_llm_reset` clears the per-shell caches.
#
# Configuration (all optional, read when a completion runs):
#
#   LLM_COMPLETE_MODEL=qwen3:latest      model must honour think:false
#   LLM_COMPLETE_URL=http://localhost:11434
#   LLM_COMPLETE_TIMEOUT=3               seconds for the model request
#   LLM_COMPLETE_KEEP_ALIVE=30m          how long Ollama pins the model
#   LLM_COMPLETE_HELP_TIMEOUT=2          seconds for `<cmd> --help`
#   LLM_COMPLETE_MAX_HELP=8192           bytes of help sent to the model
#   LLM_COMPLETE_SCREEN=1                send the visible tmux pane
#   LLM_COMPLETE_SCREEN_LINES=40
#   LLM_COMPLETE_SCREEN_BYTES=2000
#   LLM_COMPLETE_USE_FZF=1               inline picker; 0 disables it
#   LLM_COMPLETE_FZF_HEIGHT=40%
#   LLM_COMPLETE_SKIP="foo bar"          leave these to filename completion
#   LLM_COMPLETE_LOGFILE=/tmp/llm.log    enable the debug log

# Requires bash >= 4.2 (associative arrays, mapfile).

# --------------------------------------------------
# Configuration
# --------------------------------------------------
: "${LLM_COMPLETE_MODEL:=qwen3:latest}"
: "${LLM_COMPLETE_URL:=http://localhost:11434}"
: "${LLM_COMPLETE_TIMEOUT:=3}"
: "${LLM_COMPLETE_KEEP_ALIVE:=30m}"
: "${LLM_COMPLETE_HELP_TIMEOUT:=2}"
: "${LLM_COMPLETE_MAX_HELP:=8192}"
: "${LLM_COMPLETE_SCREEN:=1}"
: "${LLM_COMPLETE_SCREEN_LINES:=40}"
: "${LLM_COMPLETE_SCREEN_BYTES:=2000}"
: "${LLM_COMPLETE_USE_FZF:=1}"
: "${LLM_COMPLETE_FZF_HEIGHT:=40%}"
: "${LLM_COMPLETE_SKIP:=}"
: "${LLM_COMPLETE_LOGFILE:=}"

# Commands whose main argument is a filename: options still complete, but the
# model is not asked for arguments. Add your own with LLM_COMPLETE_SKIP.
_LLM_SKIP_CMDS=' cd pushd popd dirs pwd ls cat tac cp mv rm rmdir mkdir mktemp
    touch ln link chmod chown chgrp stat file readlink realpath basename dirname
    du df tree find locate updatedb which whereis
    less more most view vi vim nvim nano emacs ed
    sed awk gawk mawk grep egrep fgrep rg ag ack
    head tail sort uniq cut paste tr wc tee dd split csplit
    ssh scp sftp rsync ftp nc ncat netcat ping traceroute dig nslookup host whois
    curl wget aria2c man info whatis apropos
    history jobs fg bg wait kill killall pkill pgrep ps top htop
    mount umount '

# Wrappers whose own name is not the command being completed.
_LLM_WRAPPERS=' sudo doas env time nohup nice ionice stdbuf command builtin exec xargs '

# Session state, populated on first use.
declare -gA _LLM_HELP_CACHE=()
declare -gA _LLM_REPLY_CACHE=()
_LLM_DEPS_CHECKED=0
_LLM_DEPS_OK=1
_LLM_TIMEOUT_READY=0
_LLM_TIMEOUT_CMD=()
_LLM_LOG_INIT_PATH=

# --------------------------------------------------
# Lazy setup (runs on the first completion, not at source)
# --------------------------------------------------
_llm_check_deps() {
    (( _LLM_DEPS_CHECKED )) && return $(( _LLM_DEPS_OK ? 0 : 1 ))
    _LLM_DEPS_CHECKED=1
    local dep
    for dep in curl jq; do
        if ! command -v -- "$dep" >/dev/null 2>&1; then
            printf 'llm_complete: %s not found, completion disabled\n' "$dep" >&2
            _LLM_DEPS_OK=0
        fi
    done
    (( _LLM_DEPS_OK ))
}

_llm_timeout_cmd() {
    (( _LLM_TIMEOUT_READY )) && return 0
    _LLM_TIMEOUT_READY=1
    if command -v timeout >/dev/null 2>&1; then
        _LLM_TIMEOUT_CMD=(timeout "$LLM_COMPLETE_HELP_TIMEOUT")
    elif command -v gtimeout >/dev/null 2>&1; then
        _LLM_TIMEOUT_CMD=(gtimeout "$LLM_COMPLETE_HELP_TIMEOUT")
    fi
}

# --------------------------------------------------
# Debug log
# --------------------------------------------------
# Enabled only when LLM_COMPLETE_LOGFILE is set. Writes a readable block per
# model call and one line per fast path; never writes to stdout/stderr. The
# path is read on every write, so setting/changing it takes effect immediately.
_llm_debug_on() { [[ -n $LLM_COMPLETE_LOGFILE ]]; }

_llm_log_init() {
    [[ -n $LLM_COMPLETE_LOGFILE ]] || return 0
    [[ $LLM_COMPLETE_LOGFILE == "$_LLM_LOG_INIT_PATH" ]] && return 0

    local path=$LLM_COMPLETE_LOGFILE
    # Keep it bounded and private.
    if [[ -f $path ]] &&
        (( $(wc -c <"$path" 2>/dev/null || echo 0) > 1048576 )); then
        mv -f "$path" "$path.1" 2>/dev/null || :
    fi
    if ! ( umask 077; : >>"$path" ) 2>/dev/null; then
        printf 'llm_complete: cannot write %s, logging disabled\n' "$path" >&2
        LLM_COMPLETE_LOGFILE=
        _LLM_LOG_INIT_PATH=
        return 1
    fi
    _LLM_LOG_INIT_PATH=$path
    return 0
}

_llm_log() {
    _llm_debug_on || return 0
    _llm_log_init || return 0
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LLM_COMPLETE_LOGFILE" 2>/dev/null
}

_llm_block() {
    _llm_debug_on || return 0
    _llm_log_init || return 0
    printf '%s\n\n' "$1" >>"$LLM_COMPLETE_LOGFILE" 2>/dev/null
}

# Microseconds since the epoch, for timings.
_llm_us() {
    if [[ -n ${EPOCHREALTIME:-} ]]; then
        printf '%s' "${EPOCHREALTIME//[!0-9]/}"
    else
        printf '%s000000' "$(date +%s)"
    fi
}

# --------------------------------------------------
# Help text cache
# --------------------------------------------------
# Sets _LLM_HELP_TEXT. Never call this with command substitution: the cache
# assignment has to happen in the current shell.
_LLM_HELP_FROM_CACHE=0
_LLM_HELP_MS=0
_LLM_HELP_TEXT=

_llm_help() {
    local cmd=$1
    if [[ -n ${_LLM_HELP_CACHE[$cmd]+set} ]]; then
        _LLM_HELP_TEXT=${_LLM_HELP_CACHE[$cmd]}
        _LLM_HELP_FROM_CACHE=1
        _LLM_HELP_MS=0
        return 0
    fi

    _llm_help_timeout() { :; }  # placeholder removed below
    _llm_timeout_cmd

    _LLM_HELP_TEXT=
    _LLM_HELP_FROM_CACHE=0
    local t0
    t0=$(_llm_us)
    if [[ -n $(command -v -- "$cmd" 2>/dev/null) ]]; then
        # `timeout` can only wrap external commands, not shell functions.
        local -a limit=()
        [[ $(type -t -- "$cmd") == function ]] || limit=("${_LLM_TIMEOUT_CMD[@]}")
        # Some tools page their help; force plain output and no stdin.
        _LLM_HELP_TEXT=$(
            PAGER=cat MANPAGER=cat GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 \
                COLUMNS=100 LESS=FRX \
                "${limit[@]}" "$cmd" --help </dev/null 2>&1 |
                head -c "$LLM_COMPLETE_MAX_HELP"
        )
        if [[ -z $_LLM_HELP_TEXT ]]; then
            _LLM_HELP_TEXT=$(
                PAGER=cat MANPAGER=cat GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 \
                    COLUMNS=100 LESS=FRX \
                    "${limit[@]}" "$cmd" -h </dev/null 2>&1 |
                    head -c "$LLM_COMPLETE_MAX_HELP"
            )
        fi
        # No help: try the function body or the script source, then the man page.
        if [[ -z $_LLM_HELP_TEXT ]]; then
            local path
            path=$(command -v -- "$cmd" 2>/dev/null)
            if [[ $(type -t -- "$cmd") == function ]]; then
                _LLM_HELP_TEXT=$(declare -f -- "$cmd" 2>/dev/null | head -c "$LLM_COMPLETE_MAX_HELP")
            elif [[ -n $path && -f $path && -r $path && $(head -c 2 -- "$path" 2>/dev/null) == '#!' ]]; then
                _LLM_HELP_TEXT=$(head -c "$LLM_COMPLETE_MAX_HELP" -- "$path" 2>/dev/null)
            fi
        fi
        if [[ -z $_LLM_HELP_TEXT ]] && command -v man >/dev/null 2>&1; then
            _LLM_HELP_TEXT=$(
                PAGER=cat MANPAGER=cat MANWIDTH=100 LC_ALL=C \
                    "${limit[@]}" man "$cmd" </dev/null 2>/dev/null |
                    sed $'s/.\b//g' |
                    head -c "$LLM_COMPLETE_MAX_HELP"
            )
        fi
    fi
    _LLM_HELP_MS=$(( ($(_llm_us) - t0) / 1000 ))

    _LLM_HELP_CACHE[$cmd]=$_LLM_HELP_TEXT
    return 0
}

# --------------------------------------------------
# Terminal context (tmux)
# --------------------------------------------------
# The visible pane only, never the scrollback: enough context to see what the
# user is working on, bounded by lines and characters.
_LLM_SCREEN=
_LLM_SCREEN_LINES=0

_llm_screen() {
    _LLM_SCREEN=
    _LLM_SCREEN_LINES=0
    [[ $LLM_COMPLETE_SCREEN == 0 ]] && return 0
    [[ -n ${TMUX:-} && -n ${TMUX_PANE:-} ]] || return 0
    command -v tmux >/dev/null 2>&1 || return 0
    _llm_timeout_cmd

    local out
    out=$("${_LLM_TIMEOUT_CMD[@]}" tmux capture-pane -p -J -t "$TMUX_PANE" 2>/dev/null) || return 0
    [[ -n $out ]] || return 0

    _LLM_SCREEN=$(
        printf '%s\n' "$out" | awk -v n="$LLM_COMPLETE_SCREEN_LINES" -v maxb="$LLM_COMPLETE_SCREEN_BYTES" '
            { line[NR] = $0 }
            NF { last = NR }
            END {
                start = last - n + 1
                if (start < 1) start = 1
                total = 0
                for (i = last; i >= start; i--) {
                    add = length(line[i]) + 1
                    if (total + add > maxb && i < last) { start = i + 1; break }
                    total += add
                }
                for (i = start; i <= last; i++) print line[i]
            }'
    )

    # The last visible line is the one being edited; it is already passed as
    # the current context, so drop it here.
    local lastline=${_LLM_SCREEN##*$'\n'}
    if [[ -n $COMP_LINE && $lastline == *"$COMP_LINE" ]]; then
        [[ $_LLM_SCREEN == *$'\n'* ]] && _LLM_SCREEN=${_LLM_SCREEN%$'\n'*}
    fi

    _LLM_SCREEN_LINES=$(printf '%s\n' "$_LLM_SCREEN" | wc -l)
    return 0
}

# --------------------------------------------------
# Help-derived candidate pools
# --------------------------------------------------
# Subcommands: indented `name [<arg>]   description` rows. Prose lines have
# single spaces between words, so they do not match.
_LLM_CMDS=
_llm_extract_commands() {
    _LLM_CMDS=$(
        awk '
            /^[[:space:]]+-/ { next }
            /^[[:space:]]+[A-Za-z][A-Za-z0-9_.-]*([[:space:]]+<[^>]+>)?[[:space:]]{2,}/ {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                split(line, a, /[[:space:]]+/)
                print a[1]
            }
        ' <<<"$_LLM_HELP_TEXT" | sort -u
    )
}

# Options: long and short flags parsed out of the help text.
_LLM_OPTS=
_llm_extract_options() {
    local opt='--?[[:alnum:]][[:alnum:]_-]*' tok
    _LLM_OPTS=$(
        printf '%s\n' --help
        {
            grep -E '^[[:space:]]' <<<"$_LLM_HELP_TEXT" |
                grep -oE "(^|[[:space:]|,/([])($opt)"
            grep -vE '^[[:space:]]' <<<"$_LLM_HELP_TEXT" |
                grep -oE "(^|[|,/([])[[:space:]]*($opt)"
        } | while IFS= read -r tok; do
            tok=${tok#"${tok%%[[:alpha:]-]*}"}
            tok=${tok%%=*}
            [[ $tok == -* ]] && printf '%s\n' "$tok"
        done | sort -u
    )
}

# Values: enumerations on the help line of an option, such as
# `--output <format>   Output format: text, json, yaml`.
_LLM_VALS=
_llm_extract_values() {
    local opt=$1 line rest tok
    local -a vals=()
    _LLM_VALS=
    while IFS= read -r line; do
        [[ $line =~ (^|[^[:alnum:]_-])"$opt"([^[:alnum:]_-]|$) ]] || continue
        if [[ $line == *"$opt="* ]]; then
            rest=${line#*"$opt="}
            rest=${rest%%[[:space:]]*}
        elif [[ $line == *:* ]]; then
            rest=${line##*:}
        else
            continue
        fi
        while IFS= read -r tok; do
            tok=${tok#"${tok%%[![:space:]]*}"}
            tok=${tok%"${tok##*[![:space:]]}"}
            [[ $tok =~ ^[A-Za-z][A-Za-z0-9_.-]*$ ]] || continue
            vals+=("$tok")
        done < <(tr ',|/' '\n' <<<"$rest")
    done < <(grep -F -- "$opt" <<<"$_LLM_HELP_TEXT")

    if (( ${#vals[@]} >= 2 )); then
        _LLM_VALS=$(printf '%s\n' "${vals[@]}" | sort -u)
    fi
}

# --------------------------------------------------
# Candidate assembly
# --------------------------------------------------
_LLM_OUT=()
declare -gA _LLM_SEEN=()

_llm_offer() {
    local candidate=$1 cur=$2 present=$3
    [[ -z $candidate ]] && return 0
    [[ $candidate == *'<'* || $candidate == *'>'* ]] && return 0
    [[ $candidate == "$cur" ]] && return 0
    [[ $candidate == "$cur"* ]] || return 0
    [[ $present == *" $candidate "* ]] && return 0
    [[ -n ${_LLM_SEEN[$candidate]+set} ]] && return 0
    _LLM_SEEN[$candidate]=1
    _LLM_OUT+=("$candidate")
}

# --------------------------------------------------
# fzf picker
# --------------------------------------------------
# LLM_COMPLETE_USE_FZF=1 (default) runs fzf without probing for it; if fzf is
# missing the call fails and the normal menu is used. =0 disables the picker.
_llm_fzf_select() {
    [[ $LLM_COMPLETE_USE_FZF == 0 ]] && return 1
    [[ $- == *i* ]] || return 1
    (( ${#_LLM_OUT[@]} > 1 )) || return 1

    local sel rc
    sel=$(
        printf '%s\n' "${_LLM_OUT[@]}" |
            fzf --height="$LLM_COMPLETE_FZF_HEIGHT" --reverse --no-multi \
                --prompt='complete> ' --header="$COMP_LINE" 2>/dev/null
    )
    rc=$?

    if (( rc == 130 )); then
        _LLM_OUT=()
        compopt +o default +o bashdefault 2>/dev/null
        _llm_log "fzf cancelled line=$(printf '%q' "$COMP_LINE")"
        return 0
    fi
    if (( rc != 0 )) || [[ -z $sel ]]; then
        return 1
    fi

    _LLM_OUT=("$sel")
    _llm_log "fzf selected=$(printf '%q' "$sel")"
    return 0
}

_llm_emit() {
    local key=$1 w
    if (( ${#_LLM_OUT[@]} > 1 )); then
        _llm_fzf_select || true
    fi

    # Phrases and anything else with shell-special characters must be quoted
    # on insertion; `-o filenames` makes readline do that.
    for w in "${_LLM_OUT[@]}"; do
        if [[ $w == *[[:space:]]* || $w == *\'* || $w == *\"* ]]; then
            compopt -o filenames 2>/dev/null
            break
        fi
    done

    COMPREPLY=("${_LLM_OUT[@]}")
    if (( ${#_LLM_OUT[@]} )); then
        _LLM_REPLY_CACHE[$key]=$(printf '%s\n' "${_LLM_OUT[@]}")
    fi
}

# --------------------------------------------------
# Completion
# --------------------------------------------------
_llm_complete() {
    local cur cmd prev key base prev_opt cur_display prev_display
    local line_before line_after i j
    local -a candidates=()

    local t_start
    t_start=$(_llm_us)

    COMPREPLY=()
    _LLM_OUT=()
    _LLM_SEEN=()

    _llm_check_deps || return 0

    # After a command separator (`&&`, `;`, `|`) bash may call a -D/-I handler
    # with COMP_CWORD=-1 and an empty COMP_WORDS.
    if (( COMP_CWORD < 0 )) || (( ${#COMP_WORDS[@]} == 0 )); then
        return 0
    fi

    # 1. Find the real command, stepping over sudo/env/time/... wrappers and
    #    leading VAR=value assignments.
    i=0
    while (( i < COMP_CWORD )); do
        case ${COMP_WORDS[i]} in
            *'='*) (( i++ )) ;;
            -*) (( i++ )) ;;
            *)
                [[ $_LLM_WRAPPERS == *" ${COMP_WORDS[i]} "* ]] || break
                (( i++ ))
                ;;
        esac
    done

    cur=${COMP_WORDS[COMP_CWORD]:-}

    if (( i == COMP_CWORD )); then
        while IFS= read -r cmd; do
            candidates+=("$cmd")
        done < <(compgen -c -- "$cur" | sort -u)
        COMPREPLY=("${candidates[@]}")
        _llm_log "commands cur=$(printf '%q' "$cur") n=${#candidates[@]}"
        return 0
    fi

    cmd=${COMP_WORDS[i]}
    [[ -n $cmd ]] || return 0
    base=${cmd##*/}
    prev=
    (( COMP_CWORD > 0 )) && prev=${COMP_WORDS[COMP_CWORD - 1]:-}

    # `cmd --flag=value<TAB>`: bash splits on `=`, so the current word is the
    # value and the option is two words back.
    prev_opt=$prev
    cur_display=$cur
    if [[ $prev == '=' ]] && (( COMP_CWORD >= 2 )); then
        prev_opt=${COMP_WORDS[COMP_CWORD - 2]:-}
        cur_display=${cur:-<VALUE>}
    elif [[ -z $cur ]]; then
        cur_display='<NEW ARGUMENT>'
    fi

    # The cursor can be in the middle of the line, so show both sides.
    line_before=${COMP_LINE:0:COMP_POINT}
    line_after=${COMP_LINE:COMP_POINT}
    prev_display=$prev
    [[ $prev == '=' ]] && prev_display=$prev_opt

    # 2. Things the model cannot improve on: paths, expansions, redirects.
    case $cur in
        */* | '~'* | '$'* | '<'* | '>'* | '&'*)
            _llm_log "skip cmd=$cmd: path-like cur=$(printf '%q' "$cur")"
            return 0
            ;;
    esac
    case $prev in
        '<' | '>' | '>>' | '2>' | '&>')
            _llm_log "skip cmd=$cmd: redirect prev=$(printf '%q' "$prev")"
            return 0
            ;;
    esac

    # 3. User exclusions.
    local skip=" ${LLM_COMPLETE_SKIP//:/ } "
    if [[ -n $LLM_COMPLETE_SKIP && $skip == *" $base "* ]]; then
        _llm_log "skip cmd=$cmd: in LLM_COMPLETE_SKIP"
        return 0
    fi

    # 4. Response cache for this exact line and cursor.
    key="$cmd"$'\x1f'"$COMP_LINE"$'\x1f'"$COMP_CWORD"
    if [[ -n ${_LLM_REPLY_CACHE[$key]+set} ]]; then
        mapfile -t COMPREPLY <<<"${_LLM_REPLY_CACHE[$key]}"
        _llm_log "reply-cache hit cmd=$cmd cur=$(printf '%q' "$cur") out=${COMPREPLY[*]}"
        return 0
    fi

    # 5. Ground the candidate set in the command's help output. No help at all
    #    is fine: the model is still asked, with "(not available)".
    _llm_help "$cmd"
    if [[ -z $_LLM_HELP_TEXT ]]; then
        _llm_log "no help for cmd=$cmd (help_ms=$_LLM_HELP_MS); asking without it"
    fi

    # Words already on the line, except the one being completed.
    local present=' ' w
    for (( j = i; j < COMP_CWORD; j++ )); do
        present+="${COMP_WORDS[j]} "
    done
    for (( j = COMP_CWORD + 1; j < ${#COMP_WORDS[@]}; j++ )); do
        present+="${COMP_WORDS[j]} "
    done

    # 5a. Options, straight out of the help text. Exact, instant, no model.
    if [[ -n $_LLM_HELP_TEXT && $cur == -* ]]; then
        _llm_extract_options
        while IFS= read -r w; do
            _llm_offer "$w" "$cur" "$present"
        done <<<"$_LLM_OPTS"
        _llm_emit "$key"
        _llm_log "options cmd=$cmd cur=$(printf '%q' "$cur") help_chars=${#_LLM_HELP_TEXT}" \
            "help_ms=$_LLM_HELP_MS help_cached=$_LLM_HELP_FROM_CACHE n=${#_LLM_OUT[@]}" \
            "out=$(printf '%q' "${_LLM_OUT[*]}")"
        return 0
    fi

    # 5b. File-oriented commands stop here; Bash's filename completion is better.
    if [[ $_LLM_SKIP_CMDS == *" $base "* ]]; then
        _llm_log "skip cmd=$cmd: file-oriented command"
        return 0
    fi

    # 5c. Values enumerated on the option's own help line.
    if [[ $prev_opt == -* ]]; then
        _llm_extract_values "$prev_opt"
        if [[ -n $_LLM_VALS ]]; then
            while IFS= read -r w; do
                _llm_offer "$w" "$cur" "$present"
            done <<<"$_LLM_VALS"
            _llm_emit "$key"
            _llm_log "values cmd=$cmd opt=$prev_opt n=${#_LLM_OUT[@]}" \
                "out=$(printf '%q' "${_LLM_OUT[*]}")"
            return 0
        fi
    fi

    # 5d. Empty token right after an option: the user may be typing its value
    #     or starting another flag. Offer every option and subcommand.
    if [[ $prev_opt == -* && -z $cur && -n $_LLM_HELP_TEXT ]]; then
        _llm_extract_options
        _llm_extract_commands
        while IFS= read -r w; do
            _llm_offer "$w" "$cur" "$present"
        done <<<"$_LLM_OPTS"
        while IFS= read -r w; do
            _llm_offer "$w" "$cur" "$present"
        done <<<"$_LLM_CMDS"
        if (( ${#_LLM_OUT[@]} )); then
            _llm_emit "$key"
            _llm_log "option-or-flag cmd=$cmd prev=$prev_opt n=${#_LLM_OUT[@]}" \
                "out=$(printf '%q' "${_LLM_OUT[*]}")"
            return 0
        fi
    fi

    # 5e. Subcommands when the cursor is the very first argument.
    if (( COMP_CWORD == i + 1 )); then
        _llm_extract_commands
        if [[ -n $_LLM_CMDS ]]; then
            while IFS= read -r w; do
                _llm_offer "$w" "$cur" "$present"
            done <<<"$_LLM_CMDS"
            _llm_emit "$key"
            _llm_log "commands-help cmd=$cmd n=${#_LLM_OUT[@]}" \
                "out=$(printf '%q' "${_LLM_OUT[*]}")"
            return 0
        fi
    fi

    # 6. Terminal context.
    _llm_screen

    # 7. Static instructions, then the current context, help, pane, candidates.
    local system prompt
    system='You are a Bash completion engine. Complete the token under the cursor.
Output only completion candidates, one per line, nothing else.
Rules:
- No markdown, no numbering, no explanations, no code fences.
- The current token is the text that will be replaced; return whole replacement tokens.
- Every candidate MUST begin with the current token.
- Unless the current token is <NEW ARGUMENT> or <VALUE>: those markers mean the user typed a space or "=", so return whole arguments or values instead.
- Never repeat a word that already appears anywhere on the command line, before or after the cursor. The token being completed is the only exception.
- A candidate is usually a single word. When free text is expected (a note, message, reason, duration), a short phrase is allowed.
- A candidate may be a value for the preceding option, a new option, or a positional argument. If more than one is plausible here, return candidates of each kind.
- When the current token is <VALUE>, return values for the option named on the Option line.
- Otherwise, suggest the subcommands, options or arguments that fit the command line.
- Use the help output as the source of truth for commands and options.
- Use the terminal output for values visible there, such as container names, paths or uptimes.
- If the command help is not available, infer from the command name and the terminal output.
- If you have no good candidate, output nothing.

Example:
Before cursor: app --output j
Current token: j
Candidates:
json

Example:
Before cursor: app run 
Current token: <NEW ARGUMENT>
Candidates:
--verbose

Example:
Before cursor: note the server has been up for 
Current token: <NEW ARGUMENT>
Candidates:
7 hours

Example:
Before cursor: app --host 
After cursor (already typed, never suggest it):  --debug
Current token: <NEW ARGUMENT>
Candidates:
unix:///var/run/docker.sock'

    prompt=$(
        printf 'Before cursor: %s\n' "$line_before"
        [[ -n $line_after ]] && printf 'After cursor (already typed, never suggest it): %s\n' "$line_after"
        printf 'Current token: %s\n' "$cur_display"
        [[ $prev == '=' && -n $prev_opt ]] && printf 'Option: %s\n' "$prev_opt"
        (( COMP_CWORD > i + 1 )) && [[ -n $prev_display ]] && printf 'Previous argument: %s\n' "$prev_display"
        if [[ $prev_display == -* ]]; then
            printf 'Possible: a value for %s, or another option.\n' "$prev_display"
        fi
        printf '\n'
        if [[ -n $_LLM_HELP_TEXT ]]; then
            printf 'Command help:\n%s\n\n' "$_LLM_HELP_TEXT"
        else
            printf 'Command help: (not available; infer from the command name and terminal output)\n\n'
        fi
        if [[ -n $_LLM_SCREEN ]]; then
            printf 'Terminal output (visible pane; noisy, use only relevant lines):\n<terminal_output>\n%s\n</terminal_output>\n\n' "$_LLM_SCREEN"
        fi
        printf 'Candidates:\n'
    )
    _llm_log "prompt-lines: $(printf '%s' "$prompt" | wc -l)" 2>/dev/null

    # 8. Ask the model. Status checks are explicit so a curl failure is not
    #    masked by jq exiting successfully on empty input.
    local payload raw text
    payload=$(
        jq -n \
            --arg model "$LLM_COMPLETE_MODEL" \
            --arg system "$system" \
            --arg prompt "$prompt" \
            --arg keep "$LLM_COMPLETE_KEEP_ALIVE" \
            '{
                model: $model,
                system: $system,
                prompt: $prompt,
                stream: false,
                think: false,
                keep_alive: $keep,
                options: {
                    temperature: 0,
                    num_predict: 128,
                    stop: ["\n\n"]
                }
            }'
    ) || return 0

    local t_model
    t_model=$(_llm_us)
    raw=$(
        curl -fsS --connect-timeout 1 --max-time "$LLM_COMPLETE_TIMEOUT" \
            "$LLM_COMPLETE_URL/api/generate" \
            -H 'Content-Type: application/json' \
            -d "$payload" 2>/dev/null
    ) || {
        local total_ms=$(( ($(_llm_us) - t_start) / 1000 ))
        _llm_block "$(printf '=== %s  ERROR ===\ncmd=%s\ncur=%q\nline=%q\nmodel=%s\ncurl failed after %sms\n\n' \
            "$(date '+%F %T')" "$cmd" "$cur" "$COMP_LINE" "$LLM_COMPLETE_MODEL" "$total_ms")"
        return 0
    }
    local model_ms=$(( ($(_llm_us) - t_model) / 1000 ))
    text=$(jq -r '.response // empty' <<<"$raw" 2>/dev/null) || text=
    text=${text//\/no_think/}

    # 9. Filter the model's output into usable candidates.
    local raw_line candidate
    while IFS= read -r raw_line; do
        raw_line=${raw_line%$'\r'}
        [[ ${raw_line,,} == *no_think* ]] && continue

        raw_line=${raw_line#"${raw_line%%[![:space:]]*}"}
        raw_line=${raw_line%"${raw_line##*[![:space:]]}"}
        raw_line=${raw_line#- }
        raw_line=${raw_line#\* }
        raw_line=${raw_line#\`}
        raw_line=${raw_line#\"}
        raw_line=${raw_line#\'}
        [[ -z $raw_line ]] && continue

        if [[ $raw_line == -*' '* ]]; then
            candidate=${raw_line%%[[:space:]]*}
        else
            candidate=$raw_line
        fi

        candidate=${candidate%[.,;:]}
        candidate=${candidate%\`}
        candidate=${candidate%\"}
        candidate=${candidate%\'}

        [[ $candidate == *[[:alnum:]]* || $candidate == '--' ]] || continue

        _llm_offer "$candidate" "$cur" "$present"
    done <<<"$text"

    _llm_emit "$key"

    local reply_state=miss
    if (( ${#_LLM_OUT[@]} )); then
        reply_state="miss -> stored"
    fi

    local total_ms=$(( ($(_llm_us) - t_start) / 1000 ))
    _llm_block "$(
        printf '=== %s  MODEL ===\n' "$(date '+%F %T')"
        printf 'cmd: %s\n' "$cmd"
        printf 'cur: %q\n' "$cur"
        printf 'line: %q\n' "$COMP_LINE"
        printf 'cword: %s\n' "$COMP_CWORD"
        printf 'model: %s\n' "$LLM_COMPLETE_MODEL"
        printf 'help: %s chars, %sms, cached=%s\n' \
            "${#_LLM_HELP_TEXT}" "$_LLM_HELP_MS" "$_LLM_HELP_FROM_CACHE"
        printf 'screen: %s lines, %s chars (tmux=%s)\n' \
            "$_LLM_SCREEN_LINES" "${#_LLM_SCREEN}" "${TMUX_PANE:-none}"
        printf 'reply-cache: %s (entries=%s)\n' "$reply_state" "${#_LLM_REPLY_CACHE[@]}"
        printf 'timings: help=%sms model=%sms total=%sms\n' \
            "$_LLM_HELP_MS" "$model_ms" "$total_ms"
        printf -- '--- system ---\n%s\n' "$system"
        printf -- '--- prompt ---\n%s\n' "$prompt"
        printf -- '--- response ---\n%s\n' "$text"
        printf -- '--- candidates ---\n%s\n' "${_LLM_OUT[*]}"
    )"
}

# Clear the per-shell caches (help text and model answers).
_llm_reset() {
    _LLM_HELP_CACHE=()
    _LLM_REPLY_CACHE=()
}
