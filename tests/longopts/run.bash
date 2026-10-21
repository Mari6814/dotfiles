#!/usr/bin/env bash
# Build and run the longopts demo. No docker compose: this is a single
# stateless container, so plain build/run is enough.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../.." && pwd)
image=${LONGOPT_DEMO_IMAGE:-longopts-demo}

build() {
    docker build -f "$here/Dockerfile" -t "$image" "$repo"
}

case "${1:-verify}" in
    build)
        build
        ;;
    verify | test)
        build
        docker run --rm "$image"
        ;;
    shell | demo)
        build
        docker run --rm -it "$image" bash --rcfile /demo/demo.bash -i
        ;;
    *)
        printf 'usage: %s [verify|shell|build]\n' "$0" >&2
        exit 2
        ;;
esac
