export SOURCED="$BASH_SOURCE@`date +%H%m%S`:$SOURCED"

# Minimum token length, and minimum length for keeping a whole punctuation-heavy run
: "${TMUX_AUTOCOMPLETE_MIN:=4}"
: "${TMUX_AUTOCOMPLETE_LONG:=20}"

if [ ! -z "${TMUX:-}" ]; then
    # Capture the pane above the prompt, extract candidate tokens and let
    # the user pick one. Prints the selection; returns fzf's status
    # (130 = cancelled, 1 = no match).
    __autocomplete_from_tmux_pane_select() {
        local query=$1 cursor_y target=()
        [ -n "${TMUX_PANE:-}" ] && target=(-t "$TMUX_PANE")

        # Only capture the lines above the cursor line, so the command line
        # itself is never offered as a completion.
        cursor_y=$(tmux display-message -p "${target[@]}" '#{cursor_y}') || return
        [ "${cursor_y:-0}" -gt 0 ] || return

        tmux capture-pane -p -J "${target[@]}" -S 0 -E $((cursor_y - 1)) \
            | awk -v minlen="$TMUX_AUTOCOMPLETE_MIN" -v longlen="$TMUX_AUTOCOMPLETE_LONG" '
                BEGIN {
                    esc = sprintf("%c", 27)
                    on = esc "[7m"
                    off = esc "[0m"
                }

                {
                    line = $0
                    gsub(/\t/, " ", line)

                    # Quoted single-line strings (keep the quotes)
                    s = line
                    while (match(s, /"[^"\\]*(\\.[^"\\]*)*"|'"'"'[^'"'"']*'"'"'/)) {
                        q = substr(s, RSTART, RLENGTH)
                        content = substr(q, 2, length(q) - 2)
                        if (length(content) >= minlen && content ~ /[[:alnum:]]/)
                            emit(q)
                        s = substr(s, RSTART + RLENGTH)
                    }

                    nw = split(line, ws, /[[:space:]]+/)

                    # Values of assignments and flags: APP_KEY=..., --flag=...
                    for (k = 1; k <= nw; k++) {
                        w = ws[k]
                        if (w == "") continue
                        if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w ~ /^--?[A-Za-z0-9][A-Za-z0-9_-]*=/) {
                            rhs = substr(w, index(w, "=") + 1)
                            if (rhs != "" && rhs !~ /^["'"'"']/) rhs = trim_sentence(rhs)
                            emit(rhs)
                        }
                    }

                    # Long continuous runs, punctuation included (skip assignments)
                    for (k = 1; k <= nw; k++) {
                        w = ws[k]
                        if (w == "") continue
                        if (w ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w ~ /^--?[A-Za-z0-9][A-Za-z0-9_-]*=/) continue
                        r = trim_wrap(w)
                        if (length(r) >= longlen) emit(r)
                    }

                    # URLs and scp-like remotes
                    s = line
                    while (match(s, /[A-Za-z][A-Za-z0-9+.-]*:\/\/[^[:space:]"'"'"']+|[A-Za-z0-9_.-]+@[A-Za-z0-9_.-]+:[^[:space:]"'"'"']+/)) {
                        emit(trim_sentence(substr(s, RSTART, RLENGTH)))
                        s = substr(s, RSTART + RLENGTH)
                    }

                    # host:port
                    for (k = 1; k <= nw; k++) {
                        w = ws[k]
                        if (w ~ /^[A-Za-z0-9_.-]+:[0-9]+$/) emit(w)
                    }

                    # ${VAR} and $VAR
                    s = line
                    while (match(s, /\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*/)) {
                        emit(substr(s, RSTART, RLENGTH))
                        s = substr(s, RSTART + RLENGTH)
                    }

                    # Normal tokens, plus trimmed path form and path components
                    words = line
                    gsub(/[^[:alnum:]_.@$~\/-]/, "\n", words)
                    nt = split(words, norm, "\n")
                    for (k = 1; k <= nt; k++) {
                        t = norm[k]
                        emit(t)
                        if (t ~ /\//) {
                            p = trim_path(t)
                            emit(p)
                            np = split(p, parts, "/")
                            for (j = 1; j <= np; j++) {
                                c = parts[j]
                                if (c != "" && c != "." && c != "..") emit(c)
                            }
                        }
                    }
                }

                function emit(t,    p, s, out) {
                    if (t == "" || length(t) < minlen || t !~ /[[:alnum:]]/) return
                    if (seen[t]++) return
                    out = ""
                    s = line
                    while ((p = index(s, t)) > 0) {
                        out = out substr(s, 1, p - 1) on t off
                        s = substr(s, p + length(t))
                    }
                    printf "%s\t%s\n", t, out s
                }

                function trim_sentence(t) {
                    while (t ~ /[.,;:)\]}>"'"'"']$/) t = substr(t, 1, length(t) - 1)
                    return t
                }

                function trim_wrap(t) {
                    while (t ~ /^["'"'"'(\[{<]/) t = substr(t, 2)
                    return trim_sentence(t)
                }

                function trim_path(t) {
                    while (t ~ /[.\/]$/) t = substr(t, 1, length(t) - 1)
                    return t
                }
            ' \
            | fzf --track --select-1 --exit-0 --query "$query" \
                --delimiter='\t' --with-nth=1 --accept-nth=1 \
                --height=~40% --min-height=10 \
                --layout=reverse --info=inline-right --scheme=path \
                --bind 'load:transform-header:printf "%s\n" {2}' \
                --bind 'focus:transform-header:printf "%s\n" {2}'
    }

    __autocomplete_from_tmux_pane_buffer() {
        if [ -z "$TMUX" ]; then
            echo "autocompletion from buffer only works inside a TMUX session." >&2
            return 1
        fi
        local prefix="${READLINE_LINE:0:$READLINE_POINT}"
        local suffix="${READLINE_LINE:$READLINE_POINT}"

        # If the cursor is inside an unclosed quote, the query is everything
        # since the opening quote (spaces included); otherwise it is the last word.
        local query base open_quote="" quote_pos=-1 escaped=0 i ch
        for ((i = 0; i < ${#prefix}; i++)); do
            ch="${prefix:i:1}"
            if [ -n "$open_quote" ]; then
                if [ "$open_quote" = "'" ]; then
                    [ "$ch" = "'" ] && open_quote=""
                elif [ "$escaped" -eq 1 ]; then
                    escaped=0
                elif [ "$ch" = '\' ]; then
                    escaped=1
                elif [ "$ch" = '"' ]; then
                    open_quote=""
                fi
            elif [ "$escaped" -eq 1 ]; then
                escaped=0
            elif [ "$ch" = '\' ]; then
                escaped=1
            elif [ "$ch" = "'" ] || [ "$ch" = '"' ]; then
                open_quote="$ch"
                quote_pos=$i
            fi
        done

        if [ -n "$open_quote" ]; then
            query="${prefix:quote_pos+1}"
        else
            query="${prefix##*[[:space:]]}"
            base="${prefix%"$query"}"
        fi

        local selected
        selected=$(__autocomplete_from_tmux_pane_select "$query")

        # Esc / Ctrl-C / no match: leave the command line untouched
        [ -n "$selected" ] || return

        # Inside a quote: replace the partial quoted text when the selection is
        # itself quoted, otherwise keep the user's opening quote in place.
        if [ -n "$open_quote" ]; then
            case "$selected" in
                "$open_quote"*) base="${prefix:0:quote_pos}" ;;
                *) base="${prefix:0:quote_pos+1}" ;;
            esac
        fi

        READLINE_LINE="${base}${selected}${suffix}"
        READLINE_POINT=$(( ${#base} + ${#selected} ))
    }

    # Default completion: a command with no completion of its own gets the
    # pane picker. bash-completion's loader is asked first, and retried (124)
    # when it finds a real completion.
    __autocomplete_from_tmux_pane_complete() {
        local cmd=${1##*/} cur=${2:-} sel rc
        local before line_word typed_prefix keep i

        # No command word (blank line, or right after && / |): leave this to
        # bash's normal command and filename completion.
        if ((COMP_CWORD < 0)) || ((${#COMP_WORDS[@]} == 0)); then
            compopt -o default 2>/dev/null
            return 0
        fi

        # Commands that bash-completion can load keep their own completion.
        if declare -F __load_completion >/dev/null &&
            __load_completion "$cmd"; then
            return 124
        fi

        # Give the previous default handler (e.g. argcomplete's global one) a
        # chance at commands it knows. _completion_loader installs a _minimal
        # filename fallback for everything else; drop that spec again so it
        # does not shadow the picker on later Tabs.
        if [ -n "${__tmux_autocomplete_prev_default:-}" ] &&
            declare -F "$__tmux_autocomplete_prev_default" >/dev/null; then
            COMPREPLY=()
            "$__tmux_autocomplete_prev_default" "$@"
            rc=$?
            ((${#COMPREPLY[@]})) && return 0
            if [ "$rc" -eq 124 ]; then
                local default_spec
                default_spec=$(complete -p -- "$cmd" 2>/dev/null)
                if [ -n "$default_spec" ] && [[ $default_spec != *"-F _minimal"* ]]; then
                    return 124
                fi
                complete -r -- "$cmd" 2>/dev/null
            fi
        fi

        # Only run inside a real tmux pane with the tools available.
        if [ -z "${TMUX:-}" ] || [ -z "${TMUX_PANE:-}" ] ||
            ! command -v tmux >/dev/null 2>&1 ||
            ! command -v fzf >/dev/null 2>&1; then
            compopt -o default 2>/dev/null
            return 0
        fi

        sel=$(__autocomplete_from_tmux_pane_select "$cur")
        rc=$?
        if [ -z "$sel" ]; then
            # Esc / Ctrl-C leaves the line untouched. No candidates or an
            # error falls back to normal filename completion.
            [ "$rc" -eq 130 ] || compopt -o default 2>/dev/null
            return 0
        fi

        # Bash splits the line on COMP_WORDBREAKS (":", "=", ...), so it only
        # replaces the part after the last break. Strip the prefix it keeps,
        # or "host:84" + "host:8443" would become "host:host:8443".
        before="${COMP_LINE:0:COMP_POINT}"
        line_word="${before##*[[:space:]]}"
        typed_prefix=
        if [ -n "$cur" ] && [[ $line_word == *"$cur" ]]; then
            typed_prefix="${line_word%"$cur"}"
        elif [ -z "$cur" ]; then
            typed_prefix=$line_word
        fi
        if [ -n "$typed_prefix" ]; then
            # Strip the longest suffix of the typed prefix that the candidate
            # already starts with. For "--endpoint=https://ap" the candidate
            # "https://..." keeps "https:", so only the rest is inserted.
            keep=
            for ((i = 0; i < ${#typed_prefix}; i++)); do
                keep=${typed_prefix:i}
                [[ $sel == "$keep"* ]] && break
                keep=
            done
            [ -n "$keep" ] && sel="${sel#"$keep"}"
        fi

        COMPREPLY=("$sel")
        compopt -o nospace 2>/dev/null
    }

    # Remember the -D handler we replace, so it can still complete the commands
    # it recognizes. Set once per shell, so re-sourcing does not capture our own.
    if [ -z "${__tmux_autocomplete_prev_default:-}" ]; then
        __tmux_autocomplete_default_spec=$(complete -D -p 2>/dev/null)
        if [[ $__tmux_autocomplete_default_spec =~ -F[[:space:]]+([^[:space:]]+) ]] &&
            [ "${BASH_REMATCH[1]}" != "__autocomplete_from_tmux_pane_complete" ] &&
            [ "${BASH_REMATCH[1]}" != "_completion_loader" ]; then
            __tmux_autocomplete_prev_default=${BASH_REMATCH[1]}
        fi
        unset __tmux_autocomplete_default_spec
    fi

    complete -D -F __autocomplete_from_tmux_pane_complete

    bind -x '"\C-g": __autocomplete_from_tmux_pane_buffer'
fi
