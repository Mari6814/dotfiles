# Description
My personal shell files.


# Installation
Just run the `install` script.

```bash
./install
```
This will link all the packages to the `TARGET_DIR` directory. By default, the `TARGET_DIR` is set to `$HOME`.


# Uninstallation
Just run the `uninstall` script.

```bash
./uninstall
```


# Customizing the installation
To customize, you can select the packages you want to install
by providing the packages to install as arguments to the install script.

```bash
./install bash git
```

To change the directory where the packages are installed, you can set the `TARGET_DIR` environment variable.
```bash
TARGET_DIR=~/.local/bin ./install tmux-sessionizer
```


# Package paths
Inside a package, a path component can reference an environment variable by wrapping its name in braces:

```text
packages/bash/{XDG_DATA_HOME}/bash-completion/completions/example.bash
```

`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME` fall back to their standard locations when unset or empty. Files whose path references any other empty variable are skipped with a warning.

The `dot-` placeholder is replaced with `.`, so `dot-bashrc` is linked as `.bashrc`.

Paths that resolve to an absolute location are linked there directly. Relative paths are linked under `TARGET_DIR`.


# Debugging

The install script accepts a `-v` flag for verbose output, which will detail
the linking process.
