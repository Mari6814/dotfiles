#!/bin/bash

if [ -z $CLONE_DIR ]; then
    echo 'error: Specify the clone directory target: CLONE_DIR'
    return 1
fi

if [ ! -d $CLONE_DIR]; then
    echo 'error: CLONE_DIR is not a directory.'
    return 1
fi

git clone git@github.com:Marian6814/shell.git $CLONE_DIR || return 1
