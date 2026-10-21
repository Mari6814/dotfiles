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
#     --help                                  Show help message
#     --image=<DOCKER_IMAGE>                  Target Docker image
#     --container=<DOCKER_CONTAINER>          Target Docker container (all)
#     --running=<DOCKER_CONTAINER_RUNNING>    Target active Docker container
#     --stopped=<DOCKER_CONTAINER_STOPPED>    Target stopped Docker container
#     --cid=<DOCKER_CONTAINER_ID>             Target Docker container ID
#     --volume=<DOCKER_VOLUME>                Target Docker volume
#     --network=<DOCKER_NETWORK>              Target Docker network
#     --service=<COMPOSE_SERVICE>             Target Docker compose service
#     --dockerfile=<DOCKERFILE>               Target Dockerfile
#     --docker-context=<DOCKER_CONTEXT>       Target Docker context
#
#     --pimage=<PODMAN_IMAGE>                 Target Podman image
#     --pcontainer=<PODMAN_CONTAINER>         Target Podman container (all)
#     --prunning=<PODMAN_CONTAINER_RUNNING>   Target active Podman container
#     --pstopped=<PODMAN_CONTAINER_STOPPED>   Target stopped Podman container
#     --pcid=<PODMAN_CONTAINER_ID>            Target Podman container ID
#     --pvolume=<PODMAN_VOLUME>               Target Podman volume
#     --pnetwork=<PODMAN_NETWORK>             Target Podman network
#     --pservice=<PODMAN_COMPOSE_SERVICE>     Target Podman compose service
#
#     --branch=<GIT_BRANCH>                   Target Git branch
#     --commit=<GIT_COMMIT>                   Target Git commit hash
#     --remote=<GIT_REMOTE>                   Target Git remote
#     --tag=<GIT_TAG>                         Target Git tag
#     --tracked=<GIT_TRACKED_FILE>            Target tracked file in the repo
#     --stash=<GIT_STASH>                     Target Git stash entry
#     --worktree=<GIT_WORKTREE>               Target Git worktree
#
#     --db-user=<DATABASE_USER>               Database user context
#     --db=<DB_NAME>                          Target Database name (PSQL/MySQL)
#     --redis-key=<REDIS_KEY>                 Target Redis key
#     --target=<MAKE_TARGET>                  Makefile target
#     --mode=debug|info|warn                  Fixed set of choices
#
#     --env=<ENV_VAR>                         Environment variable
#     --unit=<SYSTEMD_SERVICE>                Systemd unit service
#     --user=<USER>                           System user
#     --group=<USER_GROUP>                    System group
#     --host=<HOST>                           Target host (incl. ~/.ssh/config aliases)
#     --cmd=<COMMAND>                         System executable command
#     --pid=<PID>                             Process ID
#     --iface=<NETWORK_INTERFACE>             Network interface
#     --device=<DEVICE_NODE>                  Device node under /dev
#     --mount=<MOUNT_POINT>                   Mount point
#     --tz=<TIMEZONE>                         System timezone
#     --locale=<LOCALE>                       System locale
#     --shell=<LOGIN_SHELL>                   Login shell
#     --term=<TERMINAL_TYPE>                  Terminal type (terminfo)
#
#     --key=<PUBLIC_KEY>                      Public key file (.pub/.asc)
#     --cert=<TLS_CERT>                       TLS certificate file (.crt/.cer/.cert/.pem)
#     --log=<LOG_FILE>                        Log file (.log)
#     --archive=<ARCHIVE_FILE>                Archive file (.tar.gz/.zip/...)
#     --config=<FILE>                         Configuration file
#     --out=<DIR>                             Output directory
#     --include=<FILE>...                     Repeatable include pattern
#     --exclude=<FILE>                        Single-use exclude pattern
#
# Options documented as `--opt=a|b|c` (also `<a|b|c>` or `[a|b|c]`) complete
# to each listed value, so `--mode=debug|info|warn` offers debug, info and warn.
# A list made up entirely of uppercase placeholders, such as `<FILE|DIR>`, is
# not a choice list and is left to the regular file/dir completion.
#
# Repetition is inferred only when the help documents it: a run of two or more
# dots attached to the option or its value (`--verbose...`, `--include=<FILE>..`)
# marks that option repeatable and signals that the convention is in use. Once
# one option is marked, every unmarked option is treated as single-use and is
# no longer offered after it has been given. With no such marker anywhere in
# the help, all options keep being offered, as before.
#
# To enable better longopts for that command, use
#
#   `complete -F _better_longopt dev_tool`



# Context variable for storing selected DB user across completions
_BETTER_LONGOPT_DB_USER=""

# Print the long options that the help text marks as repeatable.
# The accepted convention is a run of two or more dots attached either to the
# option itself (`--verbose...`) or to its value placeholder (`--include=<FILE>..`).
# A `[OPTIONS]...` on a usage line matches no option and is therefore ignored.
_better_longopt_repeatable() {
    command awk '
        {
            line = $0
            while (match(line, /--[A-Za-z0-9][A-Za-z0-9_-]*/)) {
                name = substr(line, RSTART, RLENGTH)
                rest = substr(line, RSTART + RLENGTH)
                marked = 0
                if (rest ~ /^\.\./) {
                    marked = 1
                } else if (rest ~ /^\[?=/) {
                    spec = rest
                    sub(/^\[?=/, "", spec)
                    sub(/[[:space:]].*$/, "", spec)
                    sub(/\]$/, "", spec)
                    if (spec ~ /\.\.$/) marked = 1
                }
                if (marked) print name
                line = substr(line, RSTART + RLENGTH)
            }
        }
    ' <<<"$1"
}

# Print the long options already given before the word being completed.
# Stops at `--` because everything after it is positional.
_better_longopt_used() {
    local cword=${1:-${COMP_CWORD:-0}} i w
    for ((i = 1; i < cword; i++)); do
        w=${COMP_WORDS[i]}
        [[ "$w" == -- ]] && break
        [[ "$w" == --?* ]] || continue
        printf '%s\n' "${w%%=*}"
    done
}

_better_longopt() {
    local cur prev words cword split

    if declare -f _init_completion &>/dev/null; then
        _init_completion -s || return
    else
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        cword=$COMP_CWORD
    fi

    local clean_prev="${prev%=}"

    # Extract user if previously set in the current command line buffer
    local cmd_line="${COMP_WORDS[*]}"
    if [[ "$cmd_line" =~ --db-user[=[:space:]]+([^[:space:]]+) ]]; then
        _BETTER_LONGOPT_DB_USER="${BASH_REMATCH[1]}"
    fi

    # Value completion applies only while the user is at the option's value:
    # `--opt <TAB>`, `--opt=<TAB>` or `--opt=val<TAB>`. A finished `--opt=val`
    # followed by a new word must fall through to flag/file completion, and a
    # word starting with `-` is a new option, not a value.
    if [[ "$clean_prev" == --* && "$prev" != *=* && "$cur" != -* ]]; then
        local help_text choice_spec="" spec line rest before after argtype
        help_text=$(LC_ALL=C "$1" --help 2>&1)

        # Enumerated values: `--opt=a|b|c`, also written `<a|b|c>` or `[a|b|c]`.
        # Only the `=` form is considered, so prose mentioning the option is not
        # mistaken for a choice list. The first list containing a `|` wins.
        while IFS= read -r line; do
            rest=$line
            while [[ "$rest" == *"$clean_prev"* ]]; do
                before=${rest%%"$clean_prev"*}
                after=${rest#*"$clean_prev"}
                rest=$after
                [[ "$after" == =* ]] || continue
                # Require a word boundary so `--color` does not match `--color-mode`.
                [[ "$before" == *[[:alnum:]_-] ]] && continue
                spec=${after#=}
                spec=${spec#"${spec%%[![:space:]]*}"}  # strip leading whitespace
                spec=${spec%%[[:space:]]*}             # value ends at whitespace
                spec=${spec%,}
                spec=${spec#<}
                spec=${spec#\[}
                spec=${spec%>}
                spec=${spec%\]}
                if [[ "$spec" == *'|'* ]]; then
                    choice_spec=$spec
                    break 2
                fi
            done
        done <<<"$help_text"

        if [[ -n "$choice_spec" ]]; then
            local choices=() choice choice_words="" placeholders=1
            IFS='|' read -r -a choices <<<"$choice_spec"
            for choice in "${choices[@]}"; do
                [[ -n "$choice" ]] || continue
                [[ "$choice" =~ ^[A-Z][A-Z0-9_]*$ ]] || placeholders=0
                choice_words+="$choice "
            done
            # Skip placeholder lists such as `<FILE|DIR>`; they are argtypes,
            # not literal values to offer.
            if [[ -n "$choice_words" && "$placeholders" -eq 0 ]]; then
                COMPREPLY=($(compgen -W "$choice_words" -- "$cur"))
                return 0
            fi
        fi

        argtype=$(command sed -ne "s|.*$clean_prev\[\{0,1\}=[<[]\{0,1\}\([-A-Za-z0-9_]\{1,\}\).*|\1|p" <<<"$help_text")

        case "${argtype^^}" in
            # --- PODMAN ---
            # NOTE: placed before the Docker block on purpose. PODMAN_COMPOSE_SERVICE
            # contains the substring COMPOSE_SERVICE, so the generic Docker pattern
            # below would otherwise swallow it.
            *PODMAN_IMAGE*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>')" -- "$cur"))
                    return 0
                fi
                ;;
            *PODMAN_CONTAINER_RUNNING*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman ps --format '{{.Names}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *PODMAN_CONTAINER_STOPPED*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman ps -a -f "status=exited" --format '{{.Names}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *PODMAN_CONTAINER_ID*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman ps -a --format '{{.ID}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *PODMAN_CONTAINER*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman ps -a --format '{{.Names}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *PODMAN_VOLUME*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman volume ls -q 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *PODMAN_NETWORK*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman network ls --format '{{.Name}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *PODMAN_COMPOSE_SERVICE*)
                if command -v podman &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(podman compose config --services 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;

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
            *DOCKERFILE*)
                # Name-based match, so filter _filedir output (which also keeps
                # directories) instead of filtering by extension. This lets the
                # user descend into subdirectories: --dockerfile=adir/bdir/<TAB>.
                if declare -f _filedir &>/dev/null; then
                    _filedir
                    local dockerfiles=() df f base
                    for f in "${COMPREPLY[@]}"; do
                        base="${f##*/}"
                        if [[ -d $f || $base == Dockerfile* || $base == *.dockerfile ]]; then
                            dockerfiles+=("$f")
                        fi
                    done
                    COMPREPLY=("${dockerfiles[@]}")
                    [[ ${#COMPREPLY[@]} -gt 0 ]] || _filedir
                    return 0
                fi
                ;;
            *DOCKER_CONTEXT*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker context ls --format '{{.Name}}' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *COMPOSE_SERVICE*)
                if command -v docker &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(docker compose config --services 2>/dev/null)" -- "$cur"))
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
            *GIT_TAG*)
                if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(git tag 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *GIT_TRACKED_FILE*)
                if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(git ls-files 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *GIT_STASH*)
                if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(git stash list --format='%gd' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *GIT_WORKTREE*)
                if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')" -- "$cur"))
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
            *USER_GROUP*)
                # Must come before *USER*, which would otherwise match this argtype too.
                COMPREPLY=($(compgen -g -- "$cur"))
                return 0
                ;;
            *NETWORK_INTERFACE*)
                if [[ -d /sys/class/net ]]; then
                    COMPREPLY=($(compgen -W "$(ls /sys/class/net 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *DEVICE_NODE*)
                if [[ -d /dev ]]; then
                    COMPREPLY=($(compgen -W "$(find /dev -maxdepth 1 \( -type b -o -type c \) -printf '%f\n' 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *MOUNT_POINT*)
                if command -v findmnt &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(findmnt -rn -o TARGET 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *TIMEZONE*)
                local timezones=""
                if command -v timedatectl &>/dev/null; then
                    timezones=$(timedatectl list-timezones 2>/dev/null)
                elif [[ -d /usr/share/zoneinfo ]]; then
                    timezones=$(find /usr/share/zoneinfo -type f -printf '%P\n' 2>/dev/null)
                fi
                if [[ -n "$timezones" ]]; then
                    COMPREPLY=($(compgen -W "$timezones" -- "$cur"))
                    return 0
                fi
                ;;
            *LOCALE*)
                COMPREPLY=($(compgen -W "$(locale -a 2>/dev/null)" -- "$cur"))
                return 0
                ;;
            *LOGIN_SHELL*)
                if [[ -f /etc/shells ]]; then
                    COMPREPLY=($(compgen -W "$(grep -vE '^[[:space:]]*(#|$)' /etc/shells 2>/dev/null)" -- "$cur"))
                    return 0
                fi
                ;;
            *TERMINAL_TYPE*)
                if command -v toe &>/dev/null; then
                    COMPREPLY=($(compgen -W "$(toe -a 2>/dev/null | awk '{print $1}')" -- "$cur"))
                    return 0
                fi
                ;;
            *USER*)
                COMPREPLY=($(compgen -u -- "$cur"))
                return 0
                ;;
            *HOST*)
                local hosts
                hosts=$(compgen -A hostname 2>/dev/null)
                # Include SSH config aliases (skip wildcard/negation patterns).
                if [[ -f ~/.ssh/config ]]; then
                    hosts+=$'\n'"$(awk '/^[[:space:]]*[Hh]ost[[:space:]]/ {for (i=2;i<=NF;i++) if ($i !~ /[*?!]/) print $i}' ~/.ssh/config 2>/dev/null)"
                fi
                COMPREPLY=($(compgen -W "$hosts" -- "$cur"))
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

            # --- FILE TYPES ---
            *PUBLIC_KEY*)
                # .pub = SSH public keys, .asc = ASCII-armored (PGP/GPG) public keys.
                # _filedir also matches the uppercase extension and quotes paths with spaces.
                if declare -f _filedir &>/dev/null; then
                    _filedir '@(pub|asc)'
                    # Fall back to plain file completion when no public key matches
                    [[ ${#COMPREPLY[@]} -gt 0 ]] || _filedir
                    return 0
                fi
                ;;
            *TLS_CERT*)
                if declare -f _filedir &>/dev/null; then
                    _filedir '@(crt|cer|cert|pem)'
                    [[ ${#COMPREPLY[@]} -gt 0 ]] || _filedir
                    return 0
                fi
                ;;
            *LOG_FILE*)
                if declare -f _filedir &>/dev/null; then
                    _filedir 'log'
                    [[ ${#COMPREPLY[@]} -gt 0 ]] || _filedir
                    return 0
                fi
                ;;
            *ARCHIVE_FILE*)
                if declare -f _filedir &>/dev/null; then
                    _filedir '@(tar.gz|tgz|tar.bz2|tbz2|tar.xz|txz|zip|7z|rar)'
                    [[ ${#COMPREPLY[@]} -gt 0 ]] || _filedir
                    return 0
                fi
                ;;
        esac
    fi

    # Fall back to standard _longopt for FILE, DIR, PATH, and flag listings
    _longopt "$@"

    # "Smart" repeatability: only when the help marks at least one option with
    # the repeatable convention (`--verbose...`, `--include=<FILE>..`) do we
    # assume that convention is in use. Unmarked options are then single-use
    # and disappear once already given. Without any marker the help simply
    # does not document repetition, so every option stays on offer.
    if [[ "$cur" == -* && ${#COMPREPLY[@]} -gt 0 ]]; then
        local rep_help rep_opts used_opts entry name filtered=()
        rep_help=$(LC_ALL=C "$1" --help 2>&1)
        rep_opts=$(_better_longopt_repeatable "$rep_help")
        if [[ -n "$rep_opts" ]]; then
            used_opts=$(_better_longopt_used "$cword")
            for entry in "${COMPREPLY[@]}"; do
                name=${entry%%=*}
                if [[ "$name" == --* ]] &&
                    [[ $'\n'"$used_opts"$'\n' == *$'\n'"$name"$'\n'* ]] &&
                    [[ $'\n'"$rep_opts"$'\n' != *$'\n'"$name"$'\n'* ]]; then
                    continue
                fi
                filtered+=("$entry")
            done
            COMPREPLY=("${filtered[@]}")
        fi
    fi
}
