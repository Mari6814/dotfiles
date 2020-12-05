# Description
My personal shell files.

# Installation

Use the install and uninstall scripts to install and automaticall back up the previously used scripts in $HOME by default.


# Parameters

Set `INSTALL_PREFIX` (default is `$HOME`) to specify the directory in which the files will be installed.

Set `BACKUP_DIR` (default is `$INSTALL_PREFIX/.shell-backup-dir`) to control where the old files will be stored.


# Uninstall

Use the `uninstall` script to delete the symlinks and restore the previous files from the specified or default `BACKUP_DIR` variable.

