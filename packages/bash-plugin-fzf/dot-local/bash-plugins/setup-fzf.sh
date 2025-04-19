#!/bin/bash
export FZF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/fzf"
export FZF_DIR="$LOCAL/fzf"

if [ -d "$FZF_DIR" ]; then
    source "$FZF_HOME/fzf.bash"
else
    setup-fzf() {
        rm -irf "$FZF_HOME" "$FZF_DIR"
        git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
        bash "$FZF_DIR/install" --xdg --all --no-update-rc
    }
fi

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
