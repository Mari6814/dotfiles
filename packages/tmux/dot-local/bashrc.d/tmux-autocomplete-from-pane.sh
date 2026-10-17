export SOURCED="$BASH_SOURCE@`date +%H%m%S`:$SOURCED"

# Minimum token length, and minimum length for keeping a whole punctuation-heavy run
: "${TMUX_AUTOCOMPLETE_MIN:=4}"
: "${TMUX_AUTOCOMPLETE_LONG:=20}"

if [ ! -z "${TMUX:-}" ]; then
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

        # Only capture the lines above the cursor line, so the command line
        # itself is never offered as a completion.
        local cursor_y
        cursor_y=$(tmux display-message -p '#{cursor_y}') || return
        [ "${cursor_y:-0}" -gt 0 ] || return

        local selected
        selected=$(tmux capture-pane -p -J -S 0 -E $((cursor_y - 1)) \
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
        )

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

    bind -x '"\C-g": __autocomplete_from_tmux_pane_buffer'
fi
