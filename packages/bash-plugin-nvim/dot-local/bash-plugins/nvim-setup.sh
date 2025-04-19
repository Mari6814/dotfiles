#!/bin/bash

export NVIM_HOME="$LOCAL/nvim"

if [ -d "$NVIM_HOME/bin" ]; then
    export PATH="$NVIM_HOME/bin:$PATH"
elif [ ! -x "`which nvim`" ]; then
    setup-nvim() {
        # Neovim from source
        local NVIM_SRC_DIR="$LOCAL/src/nvim"
        rm -rif "$NVIM_HOME" "$NVIM_SRC_DIR"
        echo 'installing nvim requirements: ninja-build gettext cmake curl build-essential'
        sudo apt-get install ninja-build gettext cmake curl build-essential
        git clone --single-branch --depth 1 --branch stable https://github.com/neovim/neovim "$NVIM_SRC_DIR"
        cd "$NVIM_SRC_DIR"
        make CMAKE_INSTALL_PREFIX="$NVIM_HOME" CMAKE_BUILD_TYPE=RelWithDebInfo
        make install
        cd -
    }
fi

