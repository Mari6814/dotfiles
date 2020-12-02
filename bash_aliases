
alias e="$EDITOR"
alias ebash="e ~/.bashrc && source ~/.bashrc"
alias eprofile="e ~/.profile && source ~/.profile"
alias evim="e ~/.config/nvim/init.vim"

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

function add-env-to-paths {
    echo "Making env in: ${1:?'Usage: make-env <dir>'}"
    [[ -d $1/bin ]] && export PATH="$1/bin:$PATH"
    [[ -d $1/include ]] && export CXX_INCLUDE_PATH="$1/include:$CXX_INCLUDE_PATH"
    [[ -d $1/lib ]] && export LD_LIBRARY_PATH="$1/lib:$LD_LIBRARY_PATH"
    [[ -d $1/lib ]] && export LIBRARY_PATH="$1/lib:$LIBRARY_PATH"
    [[ -d $1/lib64 ]] && export LD_LIBRARY_PATH="$1/lib64:$LD_LIBRARY_PATH"
    [[ -d $1/lib64 ]] && export LIBRARY_PATH="$1/lib64:$LIBRARY_PATH"
}
