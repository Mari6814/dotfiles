taildate() {
    # Print the date and time of the last line of a file
    tail -f "$1" | xargs -IL date +"%Y-%m-%d %H:%M:%S L"
}

# Autocompletion function for taildate
_taildate() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -f -- "$cur") )
}

# Register the autocompletion
complete -F _taildate taildate

watch-files() {
    # Exists if the watched files are touched
    watch -gt "ls -lR --full-time $@ | md5sum"
}

complete -F _taildate watch-files
