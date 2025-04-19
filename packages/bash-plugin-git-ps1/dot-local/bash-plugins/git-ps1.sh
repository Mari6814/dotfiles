#!/bin/bash

[ -f "/etc/bash_completion.d/git-prompt" ] && source /etc/bash_completion.d/git-prompt
export PS1='\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " %s")\$ '
source /usr/share/bash-completion/completions/git


