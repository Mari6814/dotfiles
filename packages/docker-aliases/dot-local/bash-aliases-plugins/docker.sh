#!/bin/bash

alias d="docker"
alias dc="docker compose"
alias de="docker exec -it"
function docker-exec() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: docker-exec <command> <container_name>"
    return 1
  fi
  if [ "$#" -lt 2 ]; then
    echo "Usage: docker-exec \"$1\" <container_name>"
    return 1
  fi
  docker exec -it "$2" "$1"
}
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

complete -F _docker_bash_autocomplete docker-exec

