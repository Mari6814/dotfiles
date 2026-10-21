# Custom archetype: a self-contained demo/test suite, not the repository build.
# There is nothing to compile: `check` and `demo` build the container image on
# demand through run.bash. With no preparation target left, help is the
# default so bare `make` stays read-only.
#
# Default: help — read-only; it must not start a build.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:

.DEFAULT_GOAL := help

.PHONY: check demo help

check:
	./run.bash verify

demo:
	./run.bash shell

help:
	@printf '%s\n' \
		'Default action: help' \
		'' \
		'  check   Run the completion assertions in the container' \
		'  demo    Open an interactive shell with `tool` completion loaded' \
		'  help    Show this help'
