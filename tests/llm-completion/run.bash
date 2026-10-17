#!/bin/bash
set -euo pipefail

session=llm-completion-test
dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
log=${TMPDIR:-/tmp}/llm-completion.log
rc=${TMPDIR:-/tmp}/llm-completion-rc.bash

restart=0
case ${1:-} in
    --restart) restart=1 ;;
    '') ;;
    *)
        printf 'usage: %s [--restart]\n' "${BASH_SOURCE[0]}" >&2
        exit 2
        ;;
esac

if ! command -v tmux >/dev/null 2>&1; then
    printf 'run.bash: tmux not found\n' >&2
    exit 1
fi

if tmux has-session -t "$session" 2>/dev/null && (( ! restart )); then
    if [[ -n ${TMUX:-} ]]; then
        tmux switch-client -t "$session"
    elif [[ -t 0 && -t 1 ]]; then
        tmux attach -t "$session"
    else
        printf 'already running: %s\n' "$session"
        printf 'attach: tmux attach -t %s\n' "$session"
    fi
    exit 0
fi

( umask 077; : >"$log" )
chmod 600 "$log"

cat >"$rc" <<EOF
source "$dir/fakectl.bash"
fakectl reset >/dev/null
export LLM_COMPLETE_LOGFILE="$log"
export LLM_COMPLETE_TIMEOUT=15
export LLM_COMPLETE_USE_FZF=1
PS1='llm-test\$ '
clear
EOF

rc_q=$(printf '%q' "$rc")
log_q=$(printf '%q' "$log")

tmux kill-session -t "$session" 2>/dev/null || true
tmux new-session -d -s "$session" -c "$HOME" "bash --rcfile $rc_q -i"
tmux split-window -h -t "$session" -c "$HOME" "tail -F $log_q"
tmux select-layout -t "$session" even-horizontal

mapfile -t panes < <(
    tmux list-panes -t "$session" -F '#{pane_left} #{pane_id}' |
        sort -n | awk '{print $2}'
)
left=${panes[0]}
right=${panes[1]}

tmux select-pane -t "$left" -T 'type here'
tmux select-pane -t "$right" -T 'llm log'
tmux set-option -t "$session" pane-border-status top
tmux set-option -t "$session" pane-border-format ' #{pane_title} '
tmux select-pane -t "$left"

if [[ -n ${TMUX:-} ]]; then
    tmux switch-client -t "$session"
elif [[ -t 0 && -t 1 ]]; then
    tmux attach -t "$session"
else
    printf 'started %s\n' "$session"
    printf 'switch: tmux switch-client -t %s\n' "$session"
    printf 'attach: tmux attach -t %s\n' "$session"
fi
