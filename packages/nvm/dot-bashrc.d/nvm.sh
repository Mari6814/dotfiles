export SOURCED="${BASH_SOURCE[0]}@$(date +%H%M%S):${SOURCED}"
export NVM_DIR="$HOME/.nvm"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    _nvm_lazy_load() {
        unset -f nvm node npm npx _nvm_lazy_load

        \. "$NVM_DIR/nvm.sh"
        [[ -s "$NVM_DIR/bash_completion" ]] &&
            \. "$NVM_DIR/bash_completion"
    }

    nvm()  { _nvm_lazy_load; nvm "$@"; }
    node() { _nvm_lazy_load; node "$@"; }
    npm()  { _nvm_lazy_load; npm "$@"; }
    npx()  { _nvm_lazy_load; npx "$@"; }
fi
