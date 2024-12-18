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


# Debugging

The install script accepts a `-v` flag for verbose output, which will detail
the linking process.
