export SOURCED="$BASH_SOURCE@`date +%H%m%S`:$SOURCED"

if [ ! -z "${TMUX:-}" ]; then
    __autocomplete_from_tmux_pane_buffer() {
        if [ -z "$TMUX" ]; then
            echo "autocompletion from buffer only works inside a TMUX session." >&2
            return 1
        fi
        local prefix="${READLINE_LINE:0:$READLINE_POINT}"
        local suffix="${READLINE_LINE:$READLINE_POINT}"
        local query="${prefix##*[[:space:]]}"

        # Only capture the lines above the cursor line, so the command line
        # itself is never offered as a completion.
        local cursor_y
        cursor_y=$(tmux display-message -p '#{cursor_y}') || return
        [ "${cursor_y:-0}" -gt 0 ] || return

        local selected
        selected=$(tmux capture-pane -p -J -S 0 -E $((cursor_y - 1)) \
            | awk '
                BEGIN { esc = sprintf("%c", 27) }
                {
                    raw = $0
                    gsub(/\t/, " ", raw)
                    words = raw
                    gsub(/[^[:alnum:]_.@$~\/-]/, "\n", words)
                    n = split(words, tok, "\n")
                    for (j = 1; j <= n; j++) {
                        w = tok[j]
                        if (length(w) < 3 || seen[w]++) continue
                        printf "%s\t%s\n", w, highlight(raw, w, esc "[7m", esc "[0m")
                    }
                }
                function highlight(str, w, on, off,    out, p) {
                    out = ""
                    while ((p = index(str, w)) > 0) {
                        out = out substr(str, 1, p - 1) on w off
                        str = substr(str, p + length(w))
                    }
                    return out str
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

        READLINE_LINE="${prefix%"$query"}$selected$suffix"
        READLINE_POINT=$(( ${#prefix} - ${#query} + ${#selected} ))
    }

    bind -x '"\C-g": __autocomplete_from_tmux_pane_buffer'
fi
