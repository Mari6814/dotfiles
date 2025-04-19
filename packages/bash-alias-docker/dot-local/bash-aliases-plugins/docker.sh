#!/bin/bash

alias d="docker"
alias dc="docker compose"
alias de="docker exec -it"
function docker-bash() {
  docker exec -it "$1" bash
}

# Autocompletion function
_docker_bash_autocomplete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local containers=$(docker ps --format '{{.Names}}')
  COMPREPLY=( $(compgen -W "$containers" -- "$cur") )
}

# Register the autocompletion function for docker-bash
complete -F _docker_bash_autocomplete docker-bash

