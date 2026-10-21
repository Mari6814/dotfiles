# shellcheck shell=bash
#
# Demo environment for _better_longopt.
#
# Sourcing this file defines:
#   * `tool`, whose --help output exercises every argtype the helper knows;
#   * `plain`, a small tool with no repeatable markers at all;
#   * fake `docker`, `podman`, `git`, `psql`, `mysql`, `redis-cli`, `make`,
#     `systemctl`, `timedatectl`, `locale`, `toe`, `findmnt`, `ps`, `ls` and
#     `find` functions that return fixed candidates;
#   * a `compgen` wrapper for the user/group/variable/command/hostname lookups;
#   * the `complete -F _better_longopt ...` registrations for both tools.
#
# No real docker/podman/git/... installation is used or required. The fakes
# are pure functions: the demo only needs them to answer the completion
# queries, it never starts or stops anything.

__longopt_demo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# bash-completion provides _init_completion, _longopt and _filedir.
if ! declare -F _init_completion >/dev/null 2>&1; then
    for __longopt_bc in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
        if [[ -r $__longopt_bc ]]; then
            # shellcheck source=/dev/null
            source "$__longopt_bc"
            break
        fi
    done
    unset __longopt_bc
fi

# The helper sits next to this file inside the image. When the repository
# itself is used, it still lives in the completions package.
if [[ -f $__longopt_demo_dir/better_longopt.bash ]]; then
    # shellcheck source=/dev/null
    source "$__longopt_demo_dir/better_longopt.bash"
else
    # shellcheck source=/dev/null
    source "$__longopt_demo_dir/../../packages/completions/{XDG_DATA_HOME}/bash-completion/helpers/better_longopt.bash"
fi
unset __longopt_demo_dir

tool() {
    cat <<'HELP'
Usage: tool [OPTIONS] [TARGET...]

Options:
  --help                                  Show this help

  --image=<DOCKER_IMAGE>                  Docker image
  --container=<DOCKER_CONTAINER>          Docker container (running and stopped)
  --running=<DOCKER_CONTAINER_RUNNING>    Running Docker container
  --stopped=<DOCKER_CONTAINER_STOPPED>    Stopped Docker container
  --cid=<DOCKER_CONTAINER_ID>             Docker container ID
  --volume=<DOCKER_VOLUME>                Docker volume
  --network=<DOCKER_NETWORK>              Docker network
  --service=<COMPOSE_SERVICE>             Docker Compose service
  --dockerfile=<DOCKERFILE>               Dockerfile
  --docker-context=<DOCKER_CONTEXT>       Docker context

  --pimage=<PODMAN_IMAGE>                 Podman image
  --pcontainer=<PODMAN_CONTAINER>         Podman container (running and stopped)
  --prunning=<PODMAN_CONTAINER_RUNNING>   Running Podman container
  --pstopped=<PODMAN_CONTAINER_STOPPED>   Stopped Podman container
  --pcid=<PODMAN_CONTAINER_ID>            Podman container ID
  --pvolume=<PODMAN_VOLUME>               Podman volume
  --pnetwork=<PODMAN_NETWORK>             Podman network
  --pservice=<PODMAN_COMPOSE_SERVICE>     Podman Compose service

  --branch=<GIT_BRANCH>                   Git branch
  --commit=<GIT_COMMIT>                   Git commit hash
  --remote=<GIT_REMOTE>                   Git remote
  --tag=<GIT_TAG>                         Git tag
  --tracked=<GIT_TRACKED_FILE>            Tracked file in the repository
  --stash=<GIT_STASH>                     Git stash entry
  --worktree=<GIT_WORKTREE>               Git worktree

  --db-user=<DATABASE_USER>               Database user
  --db=<DB_NAME>                          Database name
  --redis-key=<REDIS_KEY>                 Redis key
  --target=<MAKE_TARGET>                  Makefile target
  --mode=debug|info|warn                  Fixed set of choices
  --include=<FILE>...                     Repeatable include pattern
  --exclude=<FILE>                        Single-use exclude pattern
  --verbose...                            Repeatable verbosity flag
  --quiet                                 Single-use quiet flag
  --define=<KEY=VALUE>..                  Repeatable define

  --env=<ENV_VAR>                         Environment variable
  --unit=<SYSTEMD_SERVICE>                Systemd unit
  --user=<USER>                           System user
  --group=<USER_GROUP>                    System group
  --host=<HOST>                           Target host (incl. ~/.ssh/config aliases)
  --cmd=<COMMAND>                         Executable command
  --pid=<PID>                             Process ID
  --iface=<NETWORK_INTERFACE>             Network interface
  --device=<DEVICE_NODE>                  Device node under /dev
  --mount=<MOUNT_POINT>                   Mount point
  --tz=<TIMEZONE>                         Timezone
  --locale=<LOCALE>                       Locale
  --shell=<LOGIN_SHELL>                   Login shell
  --term=<TERMINAL_TYPE>                  Terminal type

  --key=<PUBLIC_KEY>                      Public key file (.pub/.asc)
  --cert=<TLS_CERT>                       TLS certificate (.crt/.cer/.cert/.pem)
  --log=<LOG_FILE>                        Log file (.log)
  --archive=<ARCHIVE_FILE>                Archive (.tar.gz/.zip/...)
  --config=<FILE>                         Configuration file
  --out=<DIR>                             Output directory
HELP
}

# Small tool with no repeatable marker anywhere. Used to show that filtering
# stays off entirely when the help does not document the convention: every
# option keeps being offered after use, just to be safe. `tool` already covers
# all marker variants, so only this fallback needs its own tool.
plain() {
    cat <<'HELP'
Usage: plain [OPTIONS]

Options:
  --file=<FILE>         Input file
  --tag=<TAG>           Tag
  --verbose             Verbosity flag
  --dry-run             Dry-run flag
HELP
}

# --- deterministic bash lookups ------------------------------------------
# The helper asks compgen for users, groups, variables, commands and
# hostnames. Route only those queries to fixed lists; everything else
# (_filedir's -f/-d in particular) keeps using the real builtin.
_demo_compgen_words() {
    local words=$1
    shift
    [[ ${1-} == -- ]] && shift
    builtin compgen -W "$words" -- "${1-}"
}

compgen() {
    case ${1-} in
        -u) _demo_compgen_words 'demo root' "${@:2}" ;;
        -g) _demo_compgen_words 'demo-group root' "${@:2}" ;;
        -v) _demo_compgen_words 'PATH HOME' "${@:2}" ;;
        -c) _demo_compgen_words 'bash tool' "${@:2}" ;;
        -A)
            if [[ ${2-} == hostname ]]; then
                _demo_compgen_words 'demo-host demo-alt' "${@:3}"
            else
                builtin compgen "$@"
            fi
            ;;
        *)
            builtin compgen "$@"
            ;;
    esac
}

# --- deterministic filesystem lookups ------------------------------------
ls() {
    if (($# == 1)) && [[ $1 == /sys/class/net ]]; then
        printf '%s\n' 'demo0' 'lo'
        return 0
    fi
    command ls "$@"
}

find() {
    if (($# > 0)) && [[ $1 == /dev ]]; then
        printf '%s\n' 'demo0' 'null'
        return 0
    fi
    command find "$@"
}

# --- docker ---------------------------------------------------------------
docker() {
    local sub=${1-} args=''
    shift || true
    args=" $* "
    case $sub in
        images)
            printf '%s\n' 'demo/api:latest' 'demo/web:1.0' '<none>:<none>'
            ;;
        ps)
            if [[ $args == *'{{.ID}}'* ]]; then
                printf '%s\n' 'deadbeef1234'
            elif [[ $args == *'status=exited'* ]]; then
                printf '%s\n' 'api-stopped'
            elif [[ $args == *' -a '* ]]; then
                printf '%s\n' 'api-run' 'api-stopped'
            else
                printf '%s\n' 'api-run'
            fi
            ;;
        volume)
            printf '%s\n' 'demo-vol'
            ;;
        network)
            printf '%s\n' 'demo-net'
            ;;
        context)
            printf '%s\n' 'demo-ctx'
            ;;
        compose)
            printf '%s\n' 'api' 'web'
            ;;
        *)
            return 1
            ;;
    esac
}

# --- podman ---------------------------------------------------------------
podman() {
    local sub=${1-} args=''
    shift || true
    args=" $* "
    case $sub in
        images)
            printf '%s\n' 'pod/img:latest' '<none>:<none>'
            ;;
        ps)
            if [[ $args == *'{{.ID}}'* ]]; then
                printf '%s\n' 'cafebabe'
            elif [[ $args == *'status=exited'* ]]; then
                printf '%s\n' 'pod-stopped'
            elif [[ $args == *' -a '* ]]; then
                printf '%s\n' 'pod-run' 'pod-stopped'
            else
                printf '%s\n' 'pod-run'
            fi
            ;;
        volume)
            printf '%s\n' 'pod-vol'
            ;;
        network)
            printf '%s\n' 'pod-net'
            ;;
        compose)
            printf '%s\n' 'papi' 'pweb'
            ;;
        *)
            return 1
            ;;
    esac
}

# --- git ------------------------------------------------------------------
git() {
    case ${1-} in
        rev-parse)
            printf 'true\n'
            ;;
        branch)
            printf '%s\n' 'main' 'feature/demo'
            ;;
        log)
            printf '%s\n' 'abc1234' 'def5678'
            ;;
        remote)
            printf '%s\n' 'origin' 'upstream'
            ;;
        tag)
            printf '%s\n' 'v1.0.0'
            ;;
        ls-files)
            printf '%s\n' 'README.md' 'src/main.c'
            ;;
        stash)
            printf 'stash@{0}\n'
            ;;
        worktree)
            printf 'worktree /work/tree-a\n\nworktree /work/tree-b\n'
            ;;
        *)
            return 1
            ;;
    esac
}

# --- databases ------------------------------------------------------------
psql() {
    printf '%s\n' 'demo_db|demo|UTF8'
}

mysql() {
    printf '%s\n' 'analytics'
}

redis-cli() {
    printf '%s\n' 'demo:key:1' 'demo:key:2'
}

# --- system ---------------------------------------------------------------
make() {
    printf '%s\n' 'build: deps' 'test:' 'deploy:' '.PHONY: build test deploy'
}

systemctl() {
    printf '%s\n' 'demo.service enabled' 'other.service disabled'
}

timedatectl() {
    printf '%s\n' 'Europe/Berlin' 'UTC'
}

locale() {
    printf '%s\n' 'C.UTF-8' 'en_US.UTF-8'
}

toe() {
    printf '%s\n' 'xterm-256color xterm-256color' 'screen-256color screen-256color'
}

findmnt() {
    printf '%s\n' '/' '/mnt/demo'
}

ps() {
    printf '%s\n' '1' '4242'
}

complete -F _better_longopt tool
complete -F _better_longopt plain

# --- introduction ---------------------------------------------------------
# Only the interactive shell gets the banner: verify.bash sources this file
# non-interactively and must stay quiet.
if [[ $- == *i* ]]; then
    cat <<'INTRO'
========================================
 _better_longopt completion demo
========================================
`tool` and `plain` are two fake commands whose --help output drives the
completion. Every external CLI they mention (docker, podman, git, psql,
mysql, redis-cli, make, systemctl, ...) is a fake returning fixed
candidates, so nothing on this host is started or queried.

Try (press TAB where marked):
  tool --<TAB>
  tool --image=<TAB>
  tool --mode=<TAB>
  tool --exclude=x --<TAB>    --exclude is hidden, --include remains
  tool --verbose --<TAB>      --verbose remains (marked repeatable)
  plain --tag=x --<TAB>       no markers, so every option remains

`tool --help` lists every argument type and repeatability marker.
Type exit to leave.
========================================
INTRO
fi
