# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# GENERAL SETUP
export LOCAL="$HOME/.local"
export CONFIG="$HOME/.config"
export BROWSER='/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe'
export PROMPT_DIRTRIM=3
export NVIMRC="$CONFIG/nvim/init.vim"
export VIMRC="~/.vimrc"
export EDITOR="nvim"

# Activate the activate environment file in $LOCAL
source "$LOCAL/activate"

# FZF enable autocompletion
source /usr/share/doc/fzf/examples/key-bindings.bash
source /usr/share/doc/fzf/examples/completion.bash
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# CUDA tensorflow torch
export CUDA_HOME="/usr/local/cuda"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"

# File used by my 'note' alias
export NOTES_FILE="$HOME/notes.txt"

# MASTERARBEIT CLUSTER LME
export CLUSTER="cluster.i5.informatik.uni-erlangen.de"
export LME="lme201.cs.fau.de"

