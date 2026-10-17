#!/usr/bin/env bash
# Test setup for llm_complete using the fake fakectl state machine.

_llm_test_dir=${BASH_SOURCE[0]%/*}
[[ $_llm_test_dir == "${BASH_SOURCE[0]}" ]] && _llm_test_dir=.
_llm_test_dir=$(cd -- "$_llm_test_dir" && pwd)
_llm_repo_root=$(cd -- "$_llm_test_dir/../.." && pwd)

export PATH="$_llm_test_dir/fixtures:$PATH"
export FAKECTL_STATE_DIR="${TMPDIR:-/tmp}/llm-completion-test"

source "$_llm_repo_root/packages/bash/{XDG_DATA_HOME}/bash-completion/helpers/llm_complete.bash"

unset _llm_test_dir _llm_repo_root

register_llm_completion fakectl --mode efficient \
    --allow-help 'fakectl' \
    --allow-help 'fakectl container' \
    --allow-help 'fakectl container run' \
    --allow-help 'fakectl container ps' \
    --allow-help 'fakectl container stop' \
    --allow-help 'fakectl container start' \
    --allow-help 'fakectl container rm' \
    --allow-help 'fakectl container inspect' \
    --allow-help 'fakectl image*' \
    --deny-help 'fakectl image rm*' \
    --allow-help 'fakectl image rm' \
    --context 'fakectl container stop*' \
        'fakectl container ps --quiet' \
    --context 'fakectl container start*' \
        'fakectl container ps -a -f state=stopped --quiet' \
    --context 'fakectl container rm*' \
        'fakectl container ps -a --quiet' \
    --context 'fakectl container inspect*' \
        'fakectl container ps -a --quiet' \
    --context 'fakectl container run*' \
        'fakectl image list --quiet' \
    --context 'fakectl image rm*' \
        'fakectl image list --quiet' \
    --context 'fakectl image inspect*' \
        'fakectl image list --quiet'
