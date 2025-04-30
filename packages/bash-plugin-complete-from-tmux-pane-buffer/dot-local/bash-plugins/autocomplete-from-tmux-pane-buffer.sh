#!/bin/bash

__autocomplete_from_tmux_pane_buffer() {
    if [ -z "$TMUX" ]; then
        echo "autocompletion from buffer only works inside a TMUX session." >&2
        return 1
    fi
    local prefix="${READLINE_LINE:0:$READLINE_POINT}"
    local suffix="${READLINE_LINE:$READLINE_POINT}"
    local query=`echo "$prefix" | awk '{print $NF}'`
    local selected=$(tmux capture-pane -p \
        | tr -cs '[:alnum:]_\-@\$\~/' '\n' \
        | awk '{ if (length($0) >= 3) print }' \
        | sed '$d' \
        | sort -u \
        | uniq -u \
        | fzf --track --select-1 --exit-0 --query "$query" --tmux
    )
    READLINE_LINE="${prefix%$query}$selected$suffix"
    READLINE_POINT=${#READLINE_LINE}
}

if [ ! -z "${TMUX:-}" ]; then
    bind -x '"\C-g": __autocomplete_from_tmux_pane_buffer'
fi
