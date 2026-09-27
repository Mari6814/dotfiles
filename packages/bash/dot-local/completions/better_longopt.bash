# "better" longopt is an extension to the bash-completions '_longopt' autocompletion method.
# '_longopt' generates autocompletions for a command based on its `--help` string.
#
#   `complete -F _longopt mycmd`
#
# Will extract all *LONG*opts from `mycmd --help` and based on its value, determine if
# its a flag, FILE or DIR.
#
# This `_better_longopt` extends `_longopt` by a bunch of other patterns.
# An example tool help string could look like this to make use of all its features:
#
#   Usage: dev_tool [OPTIONS]
#   Options:
#     --help                               Show help message
#     --image=<DOCKER_IMAGE>               Target Docker image
#     --container=<DOCKER_CONTAINER>       Target Docker container (all)
#     --running=<DOCKER_CONTAINER_RUNNING> Target active Docker container
#     --stopped=<DOCKER_CONTAINER_STOPPED> Target stopped Docker container
#     --cid=<DOCKER_CONTAINER_ID>          Target Docker container ID
#     --volume=<DOCKER_VOLUME>             Target Docker volume
#     --network=<DOCKER_NETWORK>           Target Docker network
#     --service=<COMPOSE_SERVICE>          Target Docker compose service
#
#     --context=<KUBE_CONTEXT>             Kubernetes context
#     --namespace=<KUBE_NAMESPACE>         Kubernetes namespace
#     --pod=<KUBE_POD>                     Kubernetes pod
#     --deploy=<KUBE_DEPLOYMENT>           Kubernetes deployment
#
#     --branch=<GIT_BRANCH>                Target Git branch
#     --commit=<GIT_COMMIT>                Target Git commit hash
#     --remote=<GIT_REMOTE>                Target Git remote
#
#     --db-user=<DATABASE_USER>            Database user context
#     --db=<DB_NAME>                       Target Database name (PSQL/MySQL)
#     --redis-key=<REDIS_KEY>              Target Redis key
#     --target=<MAKE_TARGET>               Makefile target
#
#     --env=<ENV_VAR>                      Environment variable
#     --unit=<SYSTEMD_SERVICE>             Systemd unit service
#     --user=<USER>                        System user
#     --host=<HOST>                        Target host
#     --cmd=<COMMAND>                      System executable command
#     --pid=<PID>                          Process ID
#
#     --config=<FILE>                      Configuration file
#     --out=<DIR>                          Output directory
#
# To enable better longopts for that command, use
#
#   `complete -F better_longopt dev_tool`



# Context variable for storing selected DB user across completions
_BETTER_LONGOPT_DB_USER=""

_better_longopt() {
    local cur prev words cword split

    if declare -f _init_completion &>/dev/null; then
        _init_completion -s || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
    fi

    local clean_prev="${prev%=}"

    # Extract user if previously set in the current command line buffer
    local cmd_line="${COMP_WORDS[*]}"
    if [[ "$cmd_line" =~ --db-user[=[:space:]]+([^[:space:]]+) ]]; then
        _BETTER_LONGOPT_DB_USER="${BASH_REMATCH[1]}"
    fi

    if [[ "$clean_prev" == --* ]]; then
        local argtype
        argtype=$(LC_ALL=C "$1" --help 2>&1 | command sed -ne "s|.*$clean_prev\[\{0,1\}=[<[]\{0,1\}\([-A-Za-z0-9_]\{1,\}\).*|\1|p")

        case "${argtype^^}" in
            # --- DOCKER ---
            *DOCKER_IMAGE*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')" -- "$cur"))
                    return 0
                fi
                ;;
            *DOCKER_CONTAINER_RUNNING*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker ps --format '{{.Names}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *DOCKER_CONTAINER_STOPPED*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker ps -a -f "status=exited" --format '{{.Names}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *DOCKER_CONTAINER_ID*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker ps -a --format '{{.ID}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *DOCKER_CONTAINER*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker ps -a --format '{{.Names}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *DOCKER_VOLUME*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker volume ls -q 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *DOCKER_NETWORK*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker network ls --format '{{.Name}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *COMPOSE_SERVICE*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker compose config --services 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;

            # --- KUBERNETES ---
            *KUBE_CONTEXT*)
                if command -v kubectl &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(kubectl config get-contexts -o name 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *KUBE_NAMESPACE*)
                if command -v kubectl &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(kubectl get ns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *KUBE_POD*)
                if command -v kubectl &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(kubectl get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *KUBE_DEPLOYMENT*)
                if command -v kubectl &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(kubectl get deployments -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;

            # --- GIT ---
            *GIT_BRANCH*)
                if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(git branch -a --format='%(refname:short)' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *GIT_COMMIT*)
                if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(git log -n 50 --format='%h' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *GIT_REMOTE*)
                if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(git remote 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;

            # --- DATABASES & USER CONTEXT ---
            *DATABASE_USER*|*DB_USER*)
                COMPREPLY=($(compgen -u -- "$cur"))
                return 0
                ;;
            *DB_NAME*|*DATABASE*)
                local dbs=""

                if [[ -n "$_BETTER_LONGOPT_DB_USER" ]]; then
                    if command -v psql &>/dev/null; then
                        dbs+="$(psql -U "$_BETTER_LONGOPT_DB_USER" -l -t -A 2>/dev/null | cut -d'|' -f1) "
                    fi
                    if command -v mysql &>/dev/null; then
                        dbs+="$(mysql -u "$_BETTER_LONGOPT_DB_USER" -e 'SHOW DATABASES;' -s --skip-column-names 2>/dev/null) "
                    fi
                else
                    if command -v psql &>/dev/null; then
                        dbs+="$(psql -l -t -A 2>/dev/null | cut -d'|' -f1) "
                    fi
                    if command -v mysql &>/dev/null; then
                        dbs+="$(mysql -e 'SHOW DATABASES;' -s --skip-column-names 2>/dev/null) "
                    fi
                fi

                if [[ -n "$dbs" ]]; then
                    COMPREPLY=($(compgen -W "$dbs" -- "$cur"))
                    return 0
                fi
                ;;
            *REDIS_KEY*)
                if command -v redis-cli &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(redis-cli --scan --pattern '*' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;

            # --- BUILD TOOLS & SYSTEM ---
            *MAKE_TARGET*)
                if [[ -f "./Makefile" ]]; then
                    local targets
                    targets=$(LC_ALL=C make -p -f ./Makefile 2>/dev/null | awk -F':' '/^[a-zA-Z0-9_.-]+:/ {if ($1 !~ /^\./) print $1}')
                    COMPREPLY=($(compgen -W "$targets" -- "$cur"))
                    return 0
                fi
                ;;
            *ENV_VAR*)
                COMPREPLY=($(compgen -v -- "$cur"))
                return 0
                ;;
            *SYSTEMD_SERVICE*)
                if command -v systemctl &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(systemctl list-unit-files --no-legend 2>/dev/null | awk '{print $1}')" -- "$cur"))
                    return 0
                fi
                ;;
            *USER*)
                COMPREPLY=($(compgen -u -- "$cur"))
                return 0
                ;;
            *HOST*)
                COMPREPLY=($(compgen -A hostname -- "$cur"))
                return 0
                ;;
            *COMMAND*)
                COMPREPLY=($(compgen -c -- "$cur"))
                return 0
                ;;
            *PID*)
                if command -v ps &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(ps -ax -o pid= 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
        esac
    fi

    # Fall back to standard _longopt for FILE, DIR, PATH, and flag listings
    _longopt "$@"
}
