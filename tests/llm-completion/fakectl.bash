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
    --allow-help '*' \
    --deny-help 'container stop *' \
    --deny-help 'image rm *' \
    --context 'container stop' \
        'fakectl container ps --quiet' \
    --context 'container start' \
        'fakectl container ps -a -f state=stopped --quiet' \
    --context 'container rm' \
        'fakectl container ps -a --quiet' \
    --context 'container inspect' \
        'fakectl container ps -a --quiet' \
    --context 'container run' \
        'fakectl image list --quiet' \
    --context 'image rm' \
        'fakectl image list --quiet' \
    --context 'image inspect' \
        'fakectl image list --quiet'
