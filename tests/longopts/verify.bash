#!/usr/bin/env bash
# Exercise every completion branch of _better_longopt against the demo `tool`.
# Runs entirely on fakes; nothing outside this image is queried.
set -u

__dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=/dev/null
source "$__dir/demo.bash"

export HOME=${LONGOPT_DEMO_HOME:-/demo/home}
cd "${LONGOPT_DEMO_WORKDIR:-/demo/work}" || exit 1

PASS=0
FAIL=0

run_completion() {
    local line=$1 cmd
    read -r cmd _ <<< "$line"
    COMP_LINE=$line
    COMP_POINT=${#line}
    read -r -a COMP_WORDS <<< "$line"
    COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
    if [[ $line == *' ' ]]; then
        COMP_WORDS+=("")
        COMP_CWORD=$(( COMP_CWORD + 1 ))
    fi
    COMPREPLY=()
    _better_longopt "$cmd" 2>/dev/null
}

normalize() {
    local value=$1
    [[ ${#value} -gt 1 ]] && value=${value%/}
    printf '%s\n' "${value%=}"
}

candidates() {
    local line=$1 value
    run_completion "$line"
    for value in "${COMPREPLY[@]}"; do
        normalize "$value"
    done | sort -u | paste -sd' ' -
}

assert_set() {
    local line=$1 want=$2 got
    got=$(candidates "$line")
    if [[ $got == "$want" ]]; then
        PASS=$((PASS + 1))
        printf 'ok   %-36s -> %s\n' "$line" "$got"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL %-36s\n     got:  %s\n     want: %s\n' "$line" "$got" "$want"
    fi
}

assert_has() {
    local line=$1 want=$2 got
    got=$(candidates "$line")
    if [[ " $got " == *" $want "* ]]; then
        PASS=$((PASS + 1))
        printf 'ok   %-36s has %s\n' "$line" "$want"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL %-36s missing %s (got: %s)\n' "$line" "$want" "$got"
    fi
}

assert_not() {
    local line=$1 want=$2 got
    got=$(candidates "$line")
    if [[ " $got " != *" $want "* ]]; then
        PASS=$((PASS + 1))
        printf 'ok   %-36s hides %s\n' "$line" "$want"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL %-36s should hide %s (got: %s)\n' "$line" "$want" "$got"
    fi
}

# --- docker ---------------------------------------------------------------
assert_set 'tool --image=demo/' 'demo/api:latest demo/web:1.0'
assert_set 'tool --container=' 'api-run api-stopped'
assert_set 'tool --running=' 'api-run'
assert_set 'tool --stopped=' 'api-stopped'
assert_set 'tool --cid=' 'deadbeef1234'
assert_set 'tool --volume=' 'demo-vol'
assert_set 'tool --network=' 'demo-net'
assert_set 'tool --service=' 'api web'
assert_set 'tool --dockerfile=Dock' 'Dockerfile'
assert_set 'tool --dockerfile=app' 'app.dockerfile'
assert_set 'tool --docker-context=' 'demo-ctx'

# --- podman ---------------------------------------------------------------
assert_set 'tool --pimage=pod/' 'pod/img:latest'
assert_set 'tool --pcontainer=' 'pod-run pod-stopped'
assert_set 'tool --prunning=' 'pod-run'
assert_set 'tool --pstopped=' 'pod-stopped'
assert_set 'tool --pcid=' 'cafebabe'
assert_set 'tool --pvolume=' 'pod-vol'
assert_set 'tool --pnetwork=' 'pod-net'
assert_set 'tool --pservice=' 'papi pweb'

# --- git ------------------------------------------------------------------
assert_set 'tool --branch=' 'feature/demo main'
assert_set 'tool --commit=' 'abc1234 def5678'
assert_set 'tool --remote=' 'origin upstream'
assert_set 'tool --tag=' 'v1.0.0'
assert_set 'tool --tracked=' 'README.md src/main.c'
assert_set 'tool --stash=' 'stash@{0}'
assert_set 'tool --worktree=' '/work/tree-a /work/tree-b'

# --- databases ------------------------------------------------------------
assert_set 'tool --db-user=' 'demo root'
assert_set 'tool --db=' 'analytics demo_db'
assert_set 'tool --redis-key=' 'demo:key:1 demo:key:2'

# --- build tools and system ----------------------------------------------
assert_set 'tool --target=' 'build deploy test'
assert_set 'tool --env=' 'HOME PATH'
assert_set 'tool --unit=' 'demo.service other.service'
assert_set 'tool --group=' 'demo-group root'
assert_set 'tool --user=' 'demo root'
assert_set 'tool --iface=' 'demo0 lo'
assert_set 'tool --device=' 'demo0 null'
assert_set 'tool --mount=' '/ /mnt/demo'
assert_set 'tool --tz=' 'Europe/Berlin UTC'
assert_set 'tool --locale=' 'C.UTF-8 en_US.UTF-8'
assert_set 'tool --shell=' '/bin/bash /bin/sh'
assert_set 'tool --term=' 'screen-256color xterm-256color'
assert_set 'tool --host=' 'demo-alt demo-host'
assert_set 'tool --cmd=' 'bash tool'
assert_set 'tool --pid=' '1 4242'

# --- file types -----------------------------------------------------------
assert_set 'tool --key=id_' 'id_demo.pub'
assert_set 'tool --cert=ca' 'ca.cer ca.cert ca.pem'
assert_set 'tool --log=app' 'app.log'
assert_set 'tool --archive=pkg' 'pkg.tar.gz pkg.zip'
assert_set 'tool --config=app.c' 'app.conf'
assert_set 'tool --out=out' 'outdir'

# --- choices --------------------------------------------------------------
assert_set 'tool --mode=' 'debug info warn'
assert_set 'tool --mode=d' 'debug'
assert_set 'tool --mode=i' 'info'

# --- smart repeatability --------------------------------------------------
assert_not 'tool --exclude=x --' '--exclude'
assert_has 'tool --exclude=x --' '--include'
assert_has 'tool --include=a --' '--include'
assert_has 'tool --verbose --' '--verbose'
assert_not 'tool --quiet --' '--quiet'
assert_has 'tool --define=A=B --' '--define'
assert_not 'tool --mode=debug --' '--mode'

# --- no repeatable marker anywhere: filtering stays off ------------------
assert_has 'plain --tag=x --' '--tag'
assert_has 'plain --dry-run --' '--dry-run'

# --- space-separated marker is ignored -----------------------------------
spaced() {
    cat <<'HELP'
Usage: spaced [OPTIONS]
Options:
  --gamma <FILE>...   Marker separated by a space is ignored
  --delta             Single-use flag
HELP
}

assert_has 'spaced --gamma=x --' '--gamma'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
