set -e
sudo apt update

inode() {
    sudo apt install nodejs
    npm i -g neovim
}

ipyenv() {
    if [ ! -d ~/.pyenv ]
    then
        git clone --depth 1 https://github.com/pyenv/pyenv.git ~/.pyenv
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init -)"' >> ~/.bashrc
        source ~/.bashrc
        pyenv install 3.10
        pyenv global 3.10
        python -m pip install neovim black mypy
    fi
}

iripgrep() {
    sudo apt install ripgrep
}
