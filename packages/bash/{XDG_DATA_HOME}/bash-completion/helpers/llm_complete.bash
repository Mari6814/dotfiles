# LLM-backed Bash completion.
#
#   source llm_complete.bash
#
# Register a command and choose how its existing completion interacts with the
# model. register_llm_completion records the current `complete -p` function
# (for example _longopt or Docker's __start_docker) and installs _llm_complete.
#
#   register_llm_completion fakectl --mode efficient \
#       --allow-help 'fakectl image*' \
#       --deny-help  'fakectl image rm*' \
#       --allow-help 'fakectl image rm' \
#       --allow-help 'fakectl container stop' \
#       --context 'fakectl container stop*' 'fakectl container ps --quiet'
#
# Modes:
#   efficient  use the existing completion when it returns candidates; fall
#              back to the model only when it returns nothing (default)
#   llm-first  run the model first; use the existing completion only when the
#              model returns no candidates
#   merge      always run the existing completion and the model, then merge
#   override   forget the existing completion and use only the model
#
# Help rules:
#   --allow-help and --deny-help are evaluated in declaration order. The last
#   matching rule wins; the default is deny. The example above allows all
#   fakectl image help except `fakectl image rm ...`, then re-allows the bare
#   `fakectl image rm` position. That keeps
#   `fakectl image rm target <Tab>` from running
#   `fakectl image rm target --help`, while `fakectl image rm <Tab>` still
#   runs `fakectl image rm --help`.
#
# Context:
#   --context PATTERN COMMAND runs COMMAND and adds its output to the model
#   prompt when the base line matches PATTERN. It is repeatable; each flag
#   takes exactly two arguments. It applies to every command named on the same
#   register_llm_completion invocation. Context commands run only when the model
#   path is reached.
#
#   register_llm_completion fakectl --mode efficient \
#       --context 'fakectl container stop*' \
#           'fakectl container ps --quiet' \
#       --context 'fakectl container start*' \
#           'fakectl container ps -a -f state=stopped --quiet' \
#       --context 'fakectl image rm*' \
#           'fakectl image list --quiet'
#
#   Repeat --context for each rule. All context is supplied directly to
#   register_llm_completion.
#
# `register_llm_completion --help` documents every option, mode, and
# environment setting. `reset_llm_completion` clears the help cache.
#
# Configuration (all optional, read when a completion runs):
#
#   LLM_COMPLETE_MODEL=qwen3:latest      model must honour think:false
#   LLM_COMPLETE_URL=http://localhost:11434
#   LLM_COMPLETE_TIMEOUT=3               seconds for the model request
#   LLM_COMPLETE_KEEP_ALIVE=30m          how long Ollama pins the model
#   LLM_COMPLETE_HELP_TIMEOUT=2          seconds for `<base> --help`
#   LLM_COMPLETE_MAX_HELP=8192           bytes of help sent to the model
#   LLM_COMPLETE_CONTEXT_TIMEOUT=1       seconds for a --context command
#   LLM_COMPLETE_CONTEXT_BYTES=2048      bytes per context command
#   LLM_COMPLETE_MAX_CONTEXT=4096        total bytes of context output
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
: "${LLM_COMPLETE_CONTEXT_TIMEOUT:=1}"
: "${LLM_COMPLETE_CONTEXT_BYTES:=2048}"
: "${LLM_COMPLETE_MAX_CONTEXT:=4096}"
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
declare -gA _LLM_HELP_RULES=()
declare -gA _LLM_MODES=()
declare -gA _LLM_CONTEXT_RULES=()
declare -gA _LLM_ORIG_FUNC=()
declare -gA _LLM_ORIG_WORDS=()
declare -gA _LLM_ORIG_SPEC=()
_LLM_DEPS_CHECKED=0
_LLM_DEPS_OK=1
_LLM_TIMEOUT_READY=0
_LLM_TIMEOUT_CMD=()
_LLM_LOG_INIT_PATH=

# Per-completion state.
_LLM_ORIG_OUT=()
_LLM_CTX_CMDS=()
_LLM_CTX_PROMPT=
_LLM_CTX_MS=0
_LLM_BASE_MATCH=
_LLM_BASE_WORDS=()
_LLM_HELP_ARGV=()
_LLM_HELP_CMD_DISPLAY=

# --------------------------------------------------
# Lazy setup (runs on the first completion, not at source)
# --------------------------------------------------
_llm_check_deps() {
    (( _LLM_DEPS_CHECKED )) && return $(( _LLM_DEPS_OK ? 0 : 1 ))
    _LLM_DEPS_CHECKED=1
    local dep
    for dep in curl jq; do
        if ! command -v -- "$dep" >/dev/null 2>&1; then
            printf 'llm_complete: %s not found, model completion disabled\n' "$dep" >&2
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
_LLM_HELP_FROM_CACHE=0
_LLM_HELP_MS=0
_LLM_HELP_TEXT=

# Sets _LLM_HELP_TEXT. Never call this with command substitution: the cache
# assignment has to happen in the current shell. The first argument is the
# cache key, the rest is the argv to run (normally `<base> --help`).
_llm_help() {
    local key=$1
    shift
    local -a argv=("$@")

    _LLM_HELP_CMD_DISPLAY=$(printf '%q ' "${argv[@]}")
    _LLM_HELP_CMD_DISPLAY=${_LLM_HELP_CMD_DISPLAY%" "}

    if [[ -n ${_LLM_HELP_CACHE[$key]+set} ]]; then
        _LLM_HELP_TEXT=${_LLM_HELP_CACHE[$key]}
        _LLM_HELP_FROM_CACHE=1
        _LLM_HELP_MS=0
        return 0
    fi

    _llm_timeout_cmd

    _LLM_HELP_TEXT=
    _LLM_HELP_FROM_CACHE=0
    local t0 first type
    t0=$(_llm_us)
    first=${argv[0]}
    type=$(type -t -- "$first" 2>/dev/null)

    if [[ -n $type ]]; then
        # `timeout` can only wrap external commands, not functions/builtins.
        local -a limit=()
        [[ $type == file ]] && limit=("${_LLM_TIMEOUT_CMD[@]}")

        # Some tools page their help; force plain output and no stdin.
        _LLM_HELP_TEXT=$(
            PAGER=cat MANPAGER=cat GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 \
                COLUMNS=100 LESS=FRX LC_ALL=C \
                "${limit[@]}" "${argv[@]}" </dev/null 2>&1 |
                head -c "$LLM_COMPLETE_MAX_HELP"
        )
        if [[ -z $_LLM_HELP_TEXT ]]; then
            local -a h_argv=("${argv[@]:0:${#argv[@]}-1}" -h)
            _LLM_HELP_TEXT=$(
                PAGER=cat MANPAGER=cat GIT_PAGER=cat GIT_TERMINAL_PROMPT=0 \
                    COLUMNS=100 LESS=FRX LC_ALL=C \
                    "${limit[@]}" "${h_argv[@]}" </dev/null 2>&1 |
                    head -c "$LLM_COMPLETE_MAX_HELP"
            )
        fi
        # No help: try the function body or the script source, then the man
        # page. This fallback only makes sense for the command itself, not for
        # `cmd subcommand --help`.
        if [[ -z $_LLM_HELP_TEXT ]] && (( ${#argv[@]} == 2 )); then
            local path
            path=$(command -v -- "$first" 2>/dev/null)
            if [[ $type == function ]]; then
                _LLM_HELP_TEXT=$(declare -f -- "$first" 2>/dev/null | head -c "$LLM_COMPLETE_MAX_HELP")
            elif [[ -n $path && -f $path && -r $path && $(head -c 2 -- "$path" 2>/dev/null) == '#!' ]]; then
                _LLM_HELP_TEXT=$(head -c "$LLM_COMPLETE_MAX_HELP" -- "$path" 2>/dev/null)
            fi
            if [[ -z $_LLM_HELP_TEXT ]] && command -v man >/dev/null 2>&1; then
                _LLM_HELP_TEXT=$(
                    PAGER=cat MANPAGER=cat MANWIDTH=100 LC_ALL=C \
                        "${limit[@]}" man "$first" </dev/null 2>/dev/null |
                        sed $'s/.\b//g' |
                        head -c "$LLM_COMPLETE_MAX_HELP"
                )
            fi
        fi
    fi
    _LLM_HELP_MS=$(( ($(_llm_us) - t0) / 1000 ))

    _LLM_HELP_CACHE[$key]=$_LLM_HELP_TEXT
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
# Per-command configuration
# --------------------------------------------------
_llm_error() {
    printf 'llm_complete: %s\n' "$*" >&2
}

_llm_add_help_rule() {
    local cmd=$1 action=$2 pattern=$3 key
    [[ -n $action && -n $pattern ]] || return 0
    key=${cmd##*/}
    if [[ -n ${_LLM_HELP_RULES[$key]:-} ]]; then
        _LLM_HELP_RULES[$key]+=$'\n'
    fi
    _LLM_HELP_RULES[$key]+="$action"$'\t'"$pattern"
    return 0
}

# Allow `<base> --help` for this command when the base line matches PATTERN.
_allow_llm_completion_help() {
    if (( $# != 2 )); then
        _llm_error "usage: _allow_llm_completion_help <command> <pattern>"
        return 2
    fi
    _llm_add_help_rule "$1" allow "$2"
}

# Deny `<base> --help` for this command when the base line matches PATTERN.
_deny_llm_completion_help() {
    if (( $# != 2 )); then
        _llm_error "usage: _deny_llm_completion_help <command> <pattern>"
        return 2
    fi
    _llm_add_help_rule "$1" deny "$2"
}

# Ordered rules; the last matching rule wins. Default is deny.
_llm_help_allowed() {
    local key=$1 base=$2 action pattern decision=1
    local rules=${_LLM_HELP_RULES[$key]-}
    [[ -n $rules ]] || return 1

    while IFS=$'\t' read -r action pattern; do
        [[ -n $action && -n $pattern ]] || continue
        [[ $base == $pattern ]] || continue
        [[ $action == allow ]] && decision=0 || decision=1
    done <<<"$rules"

    return "$decision"
}

# Run COMMAND and add its output to the model prompt when the base line
# matches PATTERN.
_add_llm_completion_context() {
    if (( $# != 3 )); then
        _llm_error "usage: _add_llm_completion_context <command> <pattern> <command-to-run>"
        return 2
    fi
    local key=${1##*/}
    [[ -n $2 && -n $3 ]] || return 0
    if [[ -n ${_LLM_CONTEXT_RULES[$key]:-} ]]; then
        _LLM_CONTEXT_RULES[$key]+=$'\n'
    fi
    _LLM_CONTEXT_RULES[$key]+="$2"$'\t'"$3"
    return 0
}

_llm_register_help() {
    cat <<'LLM_HELP_EOF'
register_llm_completion - install LLM-backed completion

Usage:
  register_llm_completion [options] <command>...
  register_llm_completion --help

For each command, register_llm_completion:
  * asks bash-completion to load the command's completion
  * records its existing completion function or word list
  * installs _llm_complete with -o bashdefault -o default
  * _llm_complete runs the recorded completion according to --mode

Modes:
  efficient  (default) The recorded completion wins when it returns
                       candidates. If it returns nothing, the LLM stages run.
  llm-first            The LLM stages run first. If they return no candidates,
                       the recorded completion is used.
  merge                Recorded completion and LLM candidates are merged.
  override             Forget the recorded completion; only the LLM stages
                       run.

  In every mode, if nothing produces candidates, COMPREPLY stays empty and
  -o default/-o bashdefault take over.

Options:
  -h, --help                 Show this help.
  --mode MODE                override, efficient, llm-first, or merge. Applies
                             to every command named on this invocation.
                             Default: efficient.
  --allow-help PATTERN       Allow `<base> --help` when the base line matches
                             PATTERN. Repeatable.
  --deny-help PATTERN        Deny `<base> --help` when the base line matches
                             PATTERN. Repeatable.
  --context PATTERN COMMAND  Run COMMAND and add its output to the model prompt
                             when the base line matches PATTERN. Repeatable;
                             each occurrence takes exactly two arguments and
                             applies to every command named on this invocation.
  --                         End options; remaining arguments are commands.

  Help rules are evaluated in declaration order. The last matching rule wins.
  The default is deny. Use a broad allow, then a narrower deny, then a
  narrower allow to re-enable a safe position.

Patterns:
  Patterns are bash globs matched against the base line: the command line from
  the real command up to the token being completed, with that token removed
  and trailing whitespace trimmed. The first word is normalized to its
  basename, so `/usr/bin/docker stop` matches `docker stop`. `*` matches
  spaces too: `docker stop*` matches `docker stop` and `docker stop xyz`;
  `docker stop` matches only the former.

  The token under the cursor is never included:
    `some -cm<Tab>`  -> base `some`        -> runs `some --help`
    `some cmd<Tab>`  -> base `some`        -> runs `some --help`
    `docker stop <Tab>` -> base `docker stop` -> runs `docker stop --help`

Examples:
  # Docker's own completion wins; the model is a fallback.
  register_llm_completion docker --mode efficient \
    --allow-help 'docker' \
    --allow-help 'docker stop'

  # Broad allow, narrow deny, narrow re-allow.
  register_llm_completion fakectl --mode efficient \
    --allow-help 'fakectl image*' \
    --deny-help 'fakectl image rm*' \
    --allow-help 'fakectl image rm'

  # Multiple contexts; each --context takes PATTERN and COMMAND.
  register_llm_completion fakectl --mode efficient \
    --allow-help 'fakectl container stop' \
    --context 'fakectl container stop*' \
        'fakectl container ps --quiet' \
    --context 'fakectl container start*' \
        'fakectl container ps -a -f state=stopped --quiet'

  # Merge the model into a command's completion.
  register_llm_completion mycmd --mode merge \
    --allow-help 'mycmd' \
    --context 'mycmd list*' 'mycmd list --quiet'

  # Use the LLM first; fall back to the recorded completion when it is empty.
  register_llm_completion mycmd --mode llm-first \
    --allow-help 'mycmd'

  # Forget the previous completion and use only the LLM path.
  register_llm_completion another --mode override \
    --allow-help 'another'

Global environment options (all optional):
  LLM_COMPLETE_MODEL=qwen3:latest      model; must honour think:false
  LLM_COMPLETE_URL=http://localhost:11434
  LLM_COMPLETE_TIMEOUT=3               seconds for the model request
  LLM_COMPLETE_KEEP_ALIVE=30m          how long Ollama pins the model
  LLM_COMPLETE_HELP_TIMEOUT=2          seconds for `<base> --help`
  LLM_COMPLETE_MAX_HELP=8192           bytes of help sent to the model
  LLM_COMPLETE_CONTEXT_TIMEOUT=1       seconds for a --context command
  LLM_COMPLETE_CONTEXT_BYTES=2048      bytes per --context command
  LLM_COMPLETE_MAX_CONTEXT=4096        total bytes of --context output
  LLM_COMPLETE_SCREEN=1                send the visible tmux pane
  LLM_COMPLETE_SCREEN_LINES=40
  LLM_COMPLETE_SCREEN_BYTES=2000
  LLM_COMPLETE_USE_FZF=1               inline picker; 0 disables it
  LLM_COMPLETE_FZF_HEIGHT=40%
  LLM_COMPLETE_SKIP="foo bar"          leave these to filename completion
  LLM_COMPLETE_LOGFILE=/tmp/llm.log    enable the debug log

Other functions:
  reset_llm_completion       clear the help cache

Notes:
  * `<base> --help` is executed as an argv (no shell expansion) and only when
    the ordered help rules allow it. Declare patterns only for commands where
    `--help` is safe and does not perform the command itself.
  * Context commands run only when the model is about to be called. They run
    with `bash -c` and receive LLM_PROGRAM, LLM_BASE, LLM_CUR, LLM_PREV, and
    LLM_LINE in their environment.
  * The model request is wrapped in `timeout`. If the timeout expires, this
    completion returns without model candidates. Ollama is a separate process
    and may finish loading the model in the background; a later Tab will use it.
LLM_HELP_EOF
}

_llm_register_one() {
    local cmd=$1 mode=$2 key=${1##*/}
    local spec= func= words=

    if [[ $mode == override ]]; then
        _LLM_ORIG_FUNC[$key]=
        _LLM_ORIG_WORDS[$key]=
        _LLM_ORIG_SPEC[$key]=
    else
        # bash-completion loads most command completions lazily. Ask it to
        # load this command's completion before recording what is registered.
        if declare -F __load_completion >/dev/null 2>&1; then
            __load_completion "$cmd" >/dev/null 2>&1 || true
        fi
        spec=$(complete -p -- "$cmd" 2>/dev/null) || spec=
        if [[ -n $spec ]]; then
            _LLM_ORIG_SPEC[$key]=$spec
            if [[ $spec =~ -F[[:space:]]+([^[:space:]]+) ]]; then
                func=${BASH_REMATCH[1]}
                if [[ $func != _llm_complete && $func != _minimal ]]; then
                    _LLM_ORIG_FUNC[$key]=$func
                fi
            elif [[ $spec =~ -W[[:space:]]+\'([^\']*)\' ]]; then
                _LLM_ORIG_WORDS[$key]=${BASH_REMATCH[1]}
            elif [[ $spec =~ -W[[:space:]]+\"([^\"]*)\" ]]; then
                _LLM_ORIG_WORDS[$key]=${BASH_REMATCH[1]}
            elif [[ $spec =~ -W[[:space:]]+([^[:space:]]+) ]]; then
                _LLM_ORIG_WORDS[$key]=${BASH_REMATCH[1]}
            fi
        fi
    fi

    complete -o bashdefault -o default -F _llm_complete -- "$cmd"
}

register_llm_completion() {
    if (( $# == 0 )) || [[ ${1-} == -h || ${1-} == --help ]]; then
        _llm_register_help
        return 0
    fi

    local -a commands=() help_rules=() context_specs=()
    local mode=efficient

    while (( $# )); do
        case $1 in
            -h | --help)
                _llm_register_help
                return 0
                ;;
            --allow-help | --deny-help)
                if (( $# < 2 )); then
                    _llm_error "$1 needs PATTERN"
                    return 2
                fi
                if [[ $1 == --allow-help ]]; then
                    help_rules+=("allow"$'\t'"$2")
                else
                    help_rules+=("deny"$'\t'"$2")
                fi
                shift 2
                ;;
            --mode)
                if (( $# < 2 )); then
                    _llm_error "--mode needs override, efficient, llm-first, or merge"
                    return 2
                fi
                case $2 in
                    override | efficient | llm-first | merge) mode=$2 ;;
                    *)
                        _llm_error "--mode must be override, efficient, llm-first, or merge"
                        return 2
                        ;;
                esac
                shift 2
                ;;
            --context)
                if (( $# < 3 )); then
                    _llm_error "--context needs PATTERN and COMMAND"
                    return 2
                fi
                context_specs+=("$2"$'\t'"$3")
                shift 3
                ;;
            --)
                shift
                commands+=("$@")
                break
                ;;
            -*)
                _llm_error "unknown option: $1"
                return 2
                ;;
            *)
                commands+=("$1")
                shift
                ;;
        esac
    done

    if (( ${#commands[@]} == 0 )); then
        _llm_error "no command given"
        _llm_register_help >&2
        return 2
    fi

    local cmd cmd_key spec action pattern context_cmd
    for cmd in "${commands[@]}"; do
        [[ -n $cmd ]] || continue
        cmd_key=${cmd##*/}
        _llm_register_one "$cmd" "$mode"
        _LLM_MODES[$cmd_key]=$mode
        for spec in "${help_rules[@]}"; do
            action=${spec%%$'\t'*}
            pattern=${spec#*$'\t'}
            case $action in
                allow) _allow_llm_completion_help "$cmd" "$pattern" ;;
                deny) _deny_llm_completion_help "$cmd" "$pattern" ;;
            esac
        done
        for spec in "${context_specs[@]}"; do
            pattern=${spec%%$'\t'*}
            context_cmd=${spec#*$'\t'}
            _add_llm_completion_context "$cmd" "$pattern" "$context_cmd"
        done
    done
}

# --------------------------------------------------
# Existing completion integration
# --------------------------------------------------
_llm_collect_original() {
    local cmd=$1 cur=$2 prev=$3 key=${1##*/}
    local func=${_LLM_ORIG_FUNC[$key]-}
    local words=${_LLM_ORIG_WORDS[$key]-}
    local c
    local -a clean=()

    _LLM_ORIG_OUT=()

    if [[ -n $func ]]; then
        local -a saved_reply=( "${COMPREPLY[@]}" )
        local -a saved_words=( "${COMP_WORDS[@]}" )
        local saved_cword=$COMP_CWORD
        local rc old_opts=$-
        COMPREPLY=()
        # Some completion functions are not `set -u`/`set -e` clean.
        set +u
        set +e
        "$func" "$cmd" "$cur" "$prev" >/dev/null 2>&1
        rc=$?
        if (( rc != 124 )); then
            _LLM_ORIG_OUT=( "${COMPREPLY[@]}" )
        fi
        COMPREPLY=( "${saved_reply[@]}" )
        COMP_WORDS=( "${saved_words[@]}" )
        COMP_CWORD=$saved_cword
        [[ $old_opts == *u* ]] && set -u
        [[ $old_opts == *e* ]] && set -e
        compopt +o filenames +o nospace 2>/dev/null || true
    elif [[ -n $words ]]; then
        mapfile -t _LLM_ORIG_OUT < <(compgen -W "$words" -- "$cur")
    fi

    for c in "${_LLM_ORIG_OUT[@]}"; do
        [[ -n $c && $c != *$'\n'* ]] && clean+=("$c")
    done
    _LLM_ORIG_OUT=( "${clean[@]}" )
    _llm_log "original func=${func:-none} words=$( [[ -n $words ]] && printf yes || printf no ) n=${#_LLM_ORIG_OUT[@]}"
}

_llm_add_orig() {
    local c
    for c in "${_LLM_ORIG_OUT[@]}"; do
        [[ -n $c ]] || continue
        [[ -n ${_LLM_SEEN[$c]+set} ]] && continue
        _LLM_SEEN[$c]=1
        _LLM_OUT+=("$c")
    done
}

# Some existing completions (notably docker's __start_docker) return entries
# like "--config     (Location of client config files)". Trim those to the
# actual word for deterministic flag/command stages.
_llm_add_orig_trim() {
    local c
    for c in "${_LLM_ORIG_OUT[@]}"; do
        [[ -n $c ]] || continue
        c=${c%%[[:space:]]*}
        [[ -n $c ]] || continue
        [[ -n ${_LLM_SEEN[$c]+set} ]] && continue
        _LLM_SEEN[$c]=1
        _LLM_OUT+=("$c")
    done
}

_llm_add_orig_flags() {
    local c
    for c in "${_LLM_ORIG_OUT[@]}"; do
        [[ $c == -* ]] || continue
        c=${c%%[[:space:]]*}
        [[ -n $c ]] || continue
        [[ -n ${_LLM_SEEN[$c]+set} ]] && continue
        _LLM_SEEN[$c]=1
        _LLM_OUT+=("$c")
    done
}

# --------------------------------------------------
# Extra context commands
# --------------------------------------------------
_llm_context_for() {
    local key=$1 base=$2 rules pat cmd c
    local seen
    _LLM_CTX_CMDS=()
    rules=${_LLM_CONTEXT_RULES[$key]-}
    [[ -n $rules ]] || return 0

    while IFS=$'\t' read -r pat cmd; do
        [[ -n $pat && -n $cmd ]] || continue
        [[ $base == $pat ]] || continue
        seen=0
        for c in "${_LLM_CTX_CMDS[@]}"; do
            [[ $c == "$cmd" ]] && seen=1 && break
        done
        (( seen )) || _LLM_CTX_CMDS+=("$cmd")
    done <<<"$rules"
}

_llm_run_context() {
    local cmd=$1 program=$2 base=$3 cur=$4 prev=$5
    local -a limit=()
    local out section label t0 ms remaining

    if command -v timeout >/dev/null 2>&1; then
        limit=(timeout "$LLM_COMPLETE_CONTEXT_TIMEOUT")
    elif command -v gtimeout >/dev/null 2>&1; then
        limit=(gtimeout "$LLM_COMPLETE_CONTEXT_TIMEOUT")
    fi

    t0=$(_llm_us)
    out=$(
        LLM_PROGRAM="$program" LLM_BASE="$base" LLM_CUR="$cur" \
            LLM_PREV="$prev" LLM_LINE="$COMP_LINE" \
            PAGER=cat MANPAGER=cat LC_ALL=C \
            "${limit[@]}" bash -c "$cmd" </dev/null 2>&1 |
            head -c "$LLM_COMPLETE_CONTEXT_BYTES"
    )
    ms=$(( ($(_llm_us) - t0) / 1000 ))
    _LLM_CTX_MS=$(( _LLM_CTX_MS + ms ))

    out=${out//$'\r'/}
    out=${out%"${out##*[![:space:]]}"}
    if [[ -z $out ]]; then
        _llm_log "context cmd=$(printf '%q' "$cmd") ms=${ms} empty"
        return 0
    fi

    remaining=$(( LLM_COMPLETE_MAX_CONTEXT - ${#_LLM_CTX_PROMPT} ))
    (( remaining > 0 )) || return 0
    if (( ${#out} > remaining )); then
        out=${out:0:remaining}
    fi

    label=${cmd//\"/\'}
    printf -v section $'\n<context source="%s">\n%s\n</context>\n' "$label" "$out"
    _LLM_CTX_PROMPT+=$section
    _llm_log "context cmd=$(printf '%q' "$cmd") ms=${ms} chars=${#out}"
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
            /^[[:space:]]+[A-Za-z][A-Za-z0-9_.*-]*([[:space:]]+<[^>]+>)?[[:space:]]{2,}/ {
                line = $0
                sub(/^[[:space:]]+/, "", line)
                split(line, a, /[[:space:]]+/)
                sub(/\*$/, "", a[1])
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
    local w
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
}

# Use the captured completion unchanged: no fzf, no model.
_llm_emit_original() {
    local base=$1 spec=${_LLM_ORIG_SPEC[$1]-}
    COMPREPLY=("${_LLM_ORIG_OUT[@]}")
    [[ $spec == *'-o filenames'* ]] && compopt -o filenames 2>/dev/null
    [[ $spec == *'-o nospace'* ]] && compopt -o nospace 2>/dev/null
    return 0
}

# Reduce a model line to the next new token after the longest suffix of the
# command line that the line repeats. For example, with line words `a b c d`
# and model output `b c d e f g`, return `e`.
_llm_merge_line() {
    local line=$1 cur=$2 present=$3 prev_opt=$4
    shift 4
    local -a line_words=("$@") toks=()
    local n=${#line_words[@]} k m best=0 match t

    if [[ -n $prev_opt && $prev_opt == -* && $prev_opt != -- && $line == "$prev_opt="* ]]; then
        line=${line#"$prev_opt="}
    fi
    # An option followed by aligned description text is not a value.
    if [[ -n $prev_opt && $prev_opt != -- &&
        $line =~ ^"$prev_opt"[[:space:]][[:space:]] ]]; then
        return 1
    fi

    read -r -a toks <<<"$line"
    (( ${#toks[@]} )) || return 1

    for (( k = 1; k <= ${#toks[@]} && k <= n; k++ )); do
        match=1
        for (( m = 0; m < k; m++ )); do
            if [[ ${toks[m]} != "${line_words[n - k + m]}" ]]; then
                match=0
                break
            fi
        done
        (( match )) && best=$k
    done

    for (( m = best; m < ${#toks[@]}; m++ )); do
        t=${toks[m]}
        [[ -n $t ]] || continue
        [[ $t == "$cur" ]] && continue
        [[ $present == *" $t "* ]] && continue
        printf '%s\n' "$t"
        return 0
    done
    return 1
}

# Read candidate lines on stdin and print one merged token per line.
# Usage: _llm_merge_completions <cur> <present> <prev_opt> <line-word...>
_llm_merge_completions() {
    local cur=$1 present=$2 prev_opt=$3
    shift 3
    local line candidate
    local -A seen=()

    while IFS= read -r line; do
        line=${line%$'\r'}
        [[ ${line,,} == *no_think* ]] && continue

        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        line=${line#- }
        line=${line#\* }
        line=${line#\`}
        line=${line#\"}
        line=${line#\'}
        [[ -z $line ]] && continue

        if ! candidate=$(_llm_merge_line "$line" "$cur" "$present" "$prev_opt" "$@"); then
            continue
        fi

        candidate=${candidate%[.,;:]}
        candidate=${candidate%\`}
        candidate=${candidate%\"}
        candidate=${candidate%\'}
        candidate=${candidate#\`}
        candidate=${candidate#\"}
        candidate=${candidate#\'}

        [[ -n $candidate ]] || continue
        [[ $candidate == "$cur"* ]] || continue
        [[ $candidate == *[[:alnum:]]* || $candidate == '--' ]] || continue
        [[ -n ${seen[$candidate]+set} ]] && continue
        seen[$candidate]=1
        printf '%s\n' "$candidate"
    done
}

# Convenience wrapper for testing the merge rule:
#   printf '%s\n' 'b c d e f g' | _merge_llm_completion '' 'a b c d'
_merge_llm_completion() {
    local cur=$1 line=$2 prev_opt=${3:-}
    local -a words=()
    read -r -a words <<<"$line"
    local present=" ${words[*]} "
    _llm_merge_completions "$cur" "$present" "$prev_opt" "${words[@]}"
}

# --------------------------------------------------
# Completion
# --------------------------------------------------
_llm_complete() {
    local cur cmd prev base mode prev_opt cur_display prev_display
    local line_before line_after i j w first help_allowed bad end help_key
    local -a candidates=()

    local t_start
    t_start=$(_llm_us)

    COMPREPLY=()
    _LLM_OUT=()
    _LLM_SEEN=()
    _LLM_ORIG_OUT=()
    _LLM_CTX_CMDS=()
    _LLM_CTX_PROMPT=
    _LLM_CTX_MS=0
        _LLM_HELP_TEXT=
    _LLM_HELP_MS=0
    _LLM_HELP_FROM_CACHE=0
    _LLM_HELP_CMD_DISPLAY=
    _LLM_BASE_MATCH=
    _LLM_BASE_WORDS=()
    _LLM_HELP_ARGV=()

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

    # 3. Capture the completion that was registered before _llm_complete.
    mode=${_LLM_MODES[$base]-efficient}
    if [[ $mode == override ]]; then
        _LLM_ORIG_OUT=()
        _llm_log "original skipped mode=override cmd=$cmd"
    else
        _llm_collect_original "$cmd" "$cur" "$prev"
    fi

    # 5. Build the base line: from the real command through the word before
    #    the token under the cursor. The token under the cursor is always
    #    excluded, even when it is empty.
    end=$COMP_CWORD
    if [[ $prev == '=' ]] && (( end >= 2 )); then
        (( end -= 2 ))
    fi
    for (( j = i; j < end; j++ )); do
        _LLM_BASE_WORDS+=("${COMP_WORDS[j]}")
    done
    _LLM_BASE_MATCH="${_LLM_BASE_WORDS[*]}"
    if (( ${#_LLM_BASE_WORDS[@]} )); then
        first=${_LLM_BASE_WORDS[0]}
        _LLM_BASE_MATCH="${first##*/}${_LLM_BASE_MATCH#"$first"}"
    fi

    # 6. In efficient mode a registered completion takes over when it produces
    #    candidates. In merge mode its candidates are kept for the LLM path.
    if [[ $mode == efficient ]] && (( ${#_LLM_ORIG_OUT[@]} )); then
        _llm_log "stage=original (prefer) cmd=$cmd mode=$mode base=$(printf '%q' "$_LLM_BASE_MATCH") n=${#_LLM_ORIG_OUT[@]}"
        _llm_emit_original "$base"
        return 0
    fi

    # 7. User exclusions: leave these to the old completion/filename completion.
    local skip=" ${LLM_COMPLETE_SKIP//:/ } "
    if [[ -n $LLM_COMPLETE_SKIP && $skip == *" $base "* ]]; then
        _llm_log "skip cmd=$cmd: in LLM_COMPLETE_SKIP"
        _llm_emit_original "$base"
        return 0
    fi

    # 8. Help is opt-in per command and per base-line pattern.
    help_allowed=0
    if _llm_help_allowed "$base" "$_LLM_BASE_MATCH"; then
        help_allowed=1
    fi
    bad=0
    for w in "${_LLM_BASE_WORDS[@]}"; do
        case $w in
            *';'* | *'|'* | *'&'* | *'<'* | *'>'* | *'$('* | *'`'*)
                bad=1
                ;;
        esac
    done
    (( bad )) && help_allowed=0

    if (( help_allowed )); then
        _LLM_HELP_ARGV=("${_LLM_BASE_WORDS[@]}" --help)
        help_key=$(printf '%q ' "${_LLM_HELP_ARGV[@]}")
        help_key=${help_key%" "}
        _llm_help "$help_key" "${_LLM_HELP_ARGV[@]}"
        _llm_log "help allowed base=$(printf '%q' "$_LLM_BASE_MATCH") cmd=$(printf '%q' "$_LLM_HELP_CMD_DISPLAY") chars=${#_LLM_HELP_TEXT} ms=$_LLM_HELP_MS cached=$_LLM_HELP_FROM_CACHE"
    else
        _llm_log "help skipped base=$(printf '%q' "$_LLM_BASE_MATCH")"
    fi

    # Words already on the line, except the one being completed.
    local present=' '
    for (( j = i; j < COMP_CWORD; j++ )); do
        present+="${COMP_WORDS[j]} "
    done
    for (( j = COMP_CWORD + 1; j < ${#COMP_WORDS[@]}; j++ )); do
        present+="${COMP_WORDS[j]} "
    done

    # 9a. Options, straight out of the help text. Exact, instant, no model.
    if [[ -n $_LLM_HELP_TEXT && $cur == -* ]]; then
        _llm_extract_options
        _llm_add_orig_flags
        while IFS= read -r w; do
            _llm_offer "$w" "$cur" "$present"
        done <<<"$_LLM_OPTS"
        if (( ${#_LLM_OUT[@]} )); then
            _llm_emit
            _llm_log "stage=options cmd=$cmd cur=$(printf '%q' "$cur") help_chars=${#_LLM_HELP_TEXT}" \
                "help_ms=$_LLM_HELP_MS help_cached=$_LLM_HELP_FROM_CACHE orig=${#_LLM_ORIG_OUT[@]}" \
                "n=${#_LLM_OUT[@]} out=$(printf '%q' "${_LLM_OUT[*]}")"
            return 0
        fi
    fi

    # 9b. Flags with no help: the old completion still knows them.
    if [[ $cur == -* ]]; then
        _llm_add_orig_flags
        if (( ${#_LLM_OUT[@]} )); then
            _llm_emit
            _llm_log "stage=flags-original cmd=$cmd n=${#_LLM_OUT[@]}" \
                "out=$(printf '%q' "${_LLM_OUT[*]}")"
            return 0
        fi
    fi

    # 9c. File-oriented commands stop here; Bash's filename completion is
    #     better for their arguments, but options above still work.
    if [[ $_LLM_SKIP_CMDS == *" $base "* ]]; then
        _llm_log "skip cmd=$cmd: file-oriented command"
        _llm_add_orig
        _llm_emit
        return 0
    fi

    # 9d. Values enumerated on the option's own help line.
    if [[ $prev_opt == -* && -n $_LLM_HELP_TEXT ]]; then
        _llm_extract_values "$prev_opt"
        if [[ -n $_LLM_VALS ]]; then
            _llm_add_orig
            while IFS= read -r w; do
                _llm_offer "$w" "$cur" "$present"
            done <<<"$_LLM_VALS"
            if (( ${#_LLM_OUT[@]} )); then
                _llm_emit
                _llm_log "stage=values cmd=$cmd opt=$prev_opt orig=${#_LLM_ORIG_OUT[@]} n=${#_LLM_OUT[@]}" \
                    "out=$(printf '%q' "${_LLM_OUT[*]}")"
                return 0
            fi
        fi
    fi

    # 9e. Subcommands, when the help for this base line has a Commands section.
    if [[ -n $_LLM_HELP_TEXT ]]; then
        _llm_extract_commands
        if [[ -n $_LLM_CMDS ]]; then
            _llm_add_orig_trim
            while IFS= read -r w; do
                _llm_offer "$w" "$cur" "$present"
            done <<<"$_LLM_CMDS"
            if (( ${#_LLM_OUT[@]} )); then
                _llm_emit
                _llm_log "stage=commands cmd=$cmd orig=${#_LLM_ORIG_OUT[@]} n=${#_LLM_OUT[@]}" \
                    "out=$(printf '%q' "${_LLM_OUT[*]}")"
                return 0
            fi
        fi
    fi

    # 10. Terminal context.
    _llm_screen

    # 11. Extra context commands, only when the model will actually run.
    _llm_context_for "$base" "$_LLM_BASE_MATCH"
    if (( ${#_LLM_CTX_CMDS[@]} )); then
        for w in "${_LLM_CTX_CMDS[@]}"; do
            _llm_run_context "$w" "$base" "$_LLM_BASE_MATCH" "$cur" "$prev"
        done
    fi

    # merge keeps the old candidates even if the model fails. llm-first keeps
    # them aside and only uses them when the model returns nothing.
    if [[ $mode != llm-first ]]; then
        _llm_add_orig
    fi

    # 12. The model is the only stage that needs curl/jq.
    if ! _llm_check_deps; then
        [[ $mode == llm-first ]] && _llm_add_orig
        _llm_emit
        return 0
    fi

    # 13. Static instructions, then the current context, help, pane, context
    #     commands, candidates.
    local system prompt
    system='You are a Bash completion engine. Complete the token under the cursor.
Output only completion candidates, one per line, nothing else.
Rules:
- No markdown, no numbering, no explanations, no code fences.
- The current token is the text that will be replaced; return whole replacement tokens.
- Every candidate MUST begin with the current token.
- Unless the current token is <NEW ARGUMENT> or <VALUE>: those markers mean the user typed a space or "=", so return whole arguments or values instead.
- Never repeat a word that already appears anywhere on the command line, before or after the cursor. The token being completed is the only exception.
- Do not return the current token by itself.
- When the Previous argument line names an option, return only its value; do not repeat the option name.
- Return exactly one token per candidate. Do not return multi-word phrases.
- A candidate may be a value for the preceding option, a new option, or a positional argument. If more than one is plausible here, return candidates of each kind.
- When the current token is <VALUE>, return values for the option named on the Option line.
- Otherwise, suggest the subcommands, options or arguments that fit the command line.
- Use the help output as the source of truth for commands and options.
- Help sections describe syntax. Context sections are live output from commands such as docker ps; use names, IDs, and values from them verbatim.
- If help and context disagree, use help for flags and subcommands and context for live values.
- Use the terminal output for values visible there, such as container names, paths or uptimes.
- If the command help is not available, infer from the command name and the terminal output.
- If you have no good candidate, output nothing.'

    prompt=$(
        printf 'Before cursor: %s\n' "$line_before"
        [[ -n $line_after ]] && printf 'After cursor (already typed, never suggest it): %s\n' "$line_after"
        printf 'Current token: %s\n' "$cur_display"
        [[ $prev == '=' && -n $prev_opt ]] && printf 'Option: %s\n' "$prev_opt"
        (( COMP_CWORD > i + 1 )) && [[ -n $prev_display ]] && printf 'Previous argument: %s\n' "$prev_display"
        if [[ $prev_display == -* ]]; then
            printf 'Possible: a value for %s, or another option.\n' "$prev_display"
        fi
        printf 'Program: %s\n' "$base"
        [[ -n $_LLM_BASE_MATCH ]] && printf 'Base line: %s\n' "$_LLM_BASE_MATCH"
        printf '\n'
        if [[ -n $_LLM_HELP_TEXT ]]; then
            printf '<help command="%s">\n%s\n</help>\n\n' "$_LLM_HELP_CMD_DISPLAY" "$_LLM_HELP_TEXT"
        else
            printf 'Command help: (not available; not allowed by configuration or no output)\n\n'
        fi
        if [[ -n $_LLM_CTX_PROMPT ]]; then
            printf '%s\n' "$_LLM_CTX_PROMPT"
        fi
        if [[ -n $_LLM_SCREEN ]]; then
            printf 'Terminal output (visible pane; noisy, use only relevant lines):\n<terminal_output>\n%s\n</terminal_output>\n\n' "$_LLM_SCREEN"
        fi
        printf 'Candidates:\n'
    )
    _llm_log "prompt-lines: $(printf '%s' "$prompt" | wc -l)" 2>/dev/null

    # 14. Ask the model. Status checks are explicit so a curl failure is not
    #     masked by jq exiting successfully on empty input.
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
    ) || {
        [[ $mode == llm-first ]] && _llm_add_orig
        _llm_emit
        return 0
    }

    local t_model
    t_model=$(_llm_us)
    local -a model_limit=() curl_limit=(curl -fsS --connect-timeout 1)
    if command -v timeout >/dev/null 2>&1; then
        model_limit=(timeout "$LLM_COMPLETE_TIMEOUT")
    elif command -v gtimeout >/dev/null 2>&1; then
        model_limit=(gtimeout "$LLM_COMPLETE_TIMEOUT")
    else
        curl_limit+=(--max-time "$LLM_COMPLETE_TIMEOUT")
    fi
    raw=$(
        "${model_limit[@]}" "${curl_limit[@]}" \
            "$LLM_COMPLETE_URL/api/generate" \
            -H 'Content-Type: application/json' \
            -d "$payload" 2>/dev/null
    ) || {
        local rc=$?
        local total_ms=$(( ($(_llm_us) - t_start) / 1000 ))
        _llm_block "$(printf '=== %s  ERROR ===\ncmd=%s\ncur=%q\nline=%q\nmodel=%s\ncurl failed after %sms (rc=%s)\n\n' \
            "$(date '+%F %T')" "$cmd" "$cur" "$COMP_LINE" "$LLM_COMPLETE_MODEL" "$total_ms" "$rc")"
        [[ $mode == llm-first ]] && _llm_add_orig
        _llm_emit
        return 0
    }
    local model_ms=$(( ($(_llm_us) - t_model) / 1000 ))
    text=$(jq -r '.response // empty' <<<"$raw" 2>/dev/null) || text=
    text=${text//\/no_think/}

    # 15. Merge the model's output into usable candidates.
    local candidate
    while IFS= read -r candidate; do
        _llm_offer "$candidate" "$cur" "$present"
    done < <(
        _llm_merge_completions "$cur" "$present" "$prev_opt" \
            "${_LLM_BASE_WORDS[@]}" <<<"$text"
    )

    if [[ $mode == llm-first ]] && (( ${#_LLM_OUT[@]} == 0 )); then
        _llm_add_orig
    fi

    local total_ms=$(( ($(_llm_us) - t_start) / 1000 ))
    _llm_block "$(
        printf '=== %s  MODEL ===\n' "$(date '+%F %T')"
        printf 'cmd: %s\n' "$cmd"
        printf 'cur: %q\n' "$cur"
        printf 'line: %q\n' "$COMP_LINE"
        printf 'cword: %s\n' "$COMP_CWORD"
        printf 'base: %s\n' "$_LLM_BASE_MATCH"
        printf 'mode: %s\n' "$mode"
        printf 'model: %s\n' "$LLM_COMPLETE_MODEL"
        printf 'original: %s candidates, func=%s\n' \
            "${#_LLM_ORIG_OUT[@]}" "${_LLM_ORIG_FUNC[$base]:-none}"
        printf 'help: %s chars, %sms, cached=%s, command=%s\n' \
            "${#_LLM_HELP_TEXT}" "$_LLM_HELP_MS" "$_LLM_HELP_FROM_CACHE" "$_LLM_HELP_CMD_DISPLAY"
        printf 'context: %s commands, %s chars, %sms\n' \
            "${#_LLM_CTX_CMDS[@]}" "${#_LLM_CTX_PROMPT}" "$_LLM_CTX_MS"
        printf 'screen: %s lines, %s chars (tmux=%s)\n' \
            "$_LLM_SCREEN_LINES" "${#_LLM_SCREEN}" "${TMUX_PANE:-none}"
        printf 'timings: help=%sms context=%sms model=%sms total=%sms\n' \
            "$_LLM_HELP_MS" "$_LLM_CTX_MS" "$model_ms" "$total_ms"
        printf -- '--- system ---\n%s\n' "$system"
        printf -- '--- prompt ---\n%s\n' "$prompt"
        printf -- '--- response ---\n%s\n' "$text"
        printf -- '--- candidates ---\n%s\n' "${_LLM_OUT[*]}"
    )"

    _llm_emit
}

# Clear the per-shell help cache.
reset_llm_completion() {
    _LLM_HELP_CACHE=()
}
