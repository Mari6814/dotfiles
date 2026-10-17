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

        local selected
        selected=$(tmux capture-pane -p -J \
            | awk 'NF { last = NR } { lines[NR] = $0 } END { for (i = 1; i < last; i++) print lines[i] }' \
            | tr -cs '[:alnum:]_\.\-@\$\~/' '\n' \
            | awk 'length($0) >= 3' \
            | sort -u \
            | fzf --track --select-1 --exit-0 --query "$query" \
                --height=~40% --min-height=10 \
                --layout=reverse --info=inline-right --scheme=path
        )

        # Esc / Ctrl-C / no match: leave the command line untouched
        [ -n "$selected" ] || return

        READLINE_LINE="${prefix%"$query"}$selected$suffix"
        READLINE_POINT=$(( ${#prefix} - ${#query} + ${#selected} ))
    }
    bind -x '"\C-g": __autocomplete_from_tmux_pane_buffer'
fi

