#!/bin/bash

ROOT_DIR="$(realpath $(dirname $0))"

if [ ! -d "$ROOT_DIR" ]; then
    echo "error: Repository not at $ROOT_DIR"
    exit 1
fi

if [ ! -f "$ROOT_DIR/install.sh" ]; then
    echo "error: Directory $ROOT_DIR is not the clone dir of this repo."
    exit 1
fi

echo "Repository root at: $ROOT_DIR"

BACKUP_DIR=$ROOT_DIR/backup

if [ -d "$BACKUP_DIR" ]; then
    echo "error: Backup directory $BACKUP_DIR already exists"
    exit 1
fi

mkdir "$BACKUP_DIR"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "error: Failed to create backup directory $BACKUP_DIR" && exit 1
    exit 1
fi

cd $HOME

FILES_TO_LINK="bashrc profile vimrc bash_aliases"

for FILE in $FILES_TO_LINK
do
    SRC_FILE="$ROOT_DIR/$FILE"
    ORIGINAL_FILE="$HOME/.$FILE"
    BACKUP_FILE="$BACKUP_DIR/$FILE"
    if [ ! -f "$SRC_FILE" ]; then
        echo "internal error: Attempt to backup $FILE, but $FILE is not provided by this repository."
        exit 1
    fi
    if [ -f "$ORIGINAL_FILE" ]; then
        echo "mv \"$ORIGINAL_FILE\" \"$BACKUP_FILE\""
        if [ -f "$BACKUP_FILE" ]; then
            echo "error: Unable to create backup of $ORIGINAL_FILE because backup already exists: $BACKUP_FILE"
            exit 1
        fi
        mv "$ORIGINAL_FILE" "$BACKUP_DIR" || (echo "error: Failed to move $FILE to backup dir $BACKUP_DIR" && exit 1)
    fi
    echo "ln -s \"$SRC_FILE\" "\"$ORIGINAL_FILE\"
    ln -s "$SRC_FILE" "$ORIGINAL_FILE" || (echo "error: Failed to link file $FILE in $SRC_FILE" && exit 1)
done
