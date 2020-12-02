
# General aliases
alias e="$EDITOR"
alias ebash="e ~/.bashrc && source ~/.bashrc"
alias eprofile="e ~/.profile && source ~/.profile"
alias evim="e ~/.config/nvim/init.vim"
alias ealias="e ~/.bash_aliases && source ~/.bash_aliases"

# Create executable bash script and edit it
function cmd {
    NAME="${1:?'Usage: cmd <name>'}"
    if [ -f $NAME ]
    then
        echo "Command already exists: $NAME"
        return 1
    fi
    echo "Creating command: $NAME"
    echo '#!/bin/bash' >> $NAME
    e $NAME
    chmod +x $NAME
}

# Start recording the comm
function reccmd {
    FILE=$1
    if [ -f $FILE ]
    then
        echo "File already exists: $FILE"
        return 1
    fi
    tee "${FILE:?'Usage: reccmd <FILE>'}" | bash
}

# PYTHON
alias pip=pip3
alias python=python3
alias jn="python -m jupyter notebook"
function ve { python -m venv ${1:-venv}; }
function va { source ${1:-*}/bin/activate; }

# NOTES
function note() { echo "$@" >> $NOTES_FILE; }
alias n=note
alias notes="cat $NOTES_FILE"
alias clrnotes="rm $NOTES_FILE"

# MASTERARBEIT CLUSTER LME
alias cluster="ssh $CLUSTER"
function lme() { ssh -L ${1:-8764}:localhost:${1:-8764} $LME; }

