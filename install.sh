#!/bin/bash

if [ -z $CLONE_DIR ]; then
    echo 'error: Specify the clone directory target: CLONE_DIR'
    return 1
fi

if [ ! -d $CLONE_DIR]; then
    echo "error: CLONE_DIR is not a directory."
    return 1
fi

echo "git clone git@github.com:Marian6814/shell.git \"$CLONE_DIR\""
git clone git@github.com:Marian6814/shell.git "$CLONE_DIR" || echo "error: Failed to clone repository" && return 1

SHELL_HOME=$CLONE_DIR/shell

if [ ! -d "$SHELL_HOME" ]; then
    echo "error: Failed to download repository to $SHELL_HOME"
    return 1
fi

BACKUP_DIR=$SHELL_HOME/backup

if [ -d "$BACKUP_DIR" ]; then
    echo "error: Backup directory $BACKUP_DIR already exists"
    return 1
fi

mkdir "$BACKUP_DIR"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "error: Failed to create backup directory $BACKUP_DIR" && return 1
    return 1
fi

cd $HOME

FILES_TO_LINK="bachrc" "profile" "vimrc" "bash_aliases"

for FILE in $FILES_TO_LINK
do
    if [ -f ".$FILE" ]; then
        echo "mv \".$FILE\" \"$BACKUP_DIR/$FILE\""
        if [ -f "$BACKUP_DIR/$FILE" ]; then
            echo "error: File $FILE already exists in backup dir $BACKUP_DIR."
            return 1
        fi
        mv ".$FILE" "$BACKUP_DIR/$FILE" || echo "error: Failed to move $FILE to backup dir $BACKUP_DIR" && return 1
        echo "ln -s \".$FILE\" \"$SHELL_HOME/$FILE\""
        ln -s .$FILE "$SHELL_HOME/$FILE" || echo "error: Failed to link file $FILE in $SHELL_HOME/$FILE" && return 1
    fi
fi