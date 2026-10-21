longopts demo
=============

Purpose
-------
Show and verify what `_better_longopt` completes for every argument type it
supports. The demo does not use real docker, podman, git, psql, mysql, redis,
make, systemd, locale or terminal tools: each one is a fake function that
prints exactly the candidates the tests expect. Nothing is started, stopped
or queried on the host.

The point is to compare the completion output with the candidates the demo
tool advertises, deterministically, on any machine.

Files
-----
  Dockerfile     debian:bookworm-slim + bash, bash-completion and awk
  demo.bash      `tool` and `plain`, all fake CLIs, completion registration
  verify.bash    assertions for every branch
  run.bash       build/run wrapper (no docker compose needed)

Usage
-----
  ./run.bash              # build, then run the assertions
  ./run.bash shell        # interactive bash with `tool` completion loaded
  ./run.bash build        # only build the image

The same via make (run from this directory):

  make            # help, the default target
  make check      # assertions
  make demo       # interactive shell

The interactive shell starts with a short banner explaining the demo and
the commands below. In it, try:

  tool --<TAB>
  tool --image=<TAB>
  tool --mode=<TAB>
  tool --exclude=x --<TAB>    # --exclude disappears, --include stays
  tool --verbose --<TAB>      # --verbose stays (marked repeatable)
  plain --tag=x --<TAB>       # no markers: --tag is offered again

The image is named `longopts-demo`; override it with LONGOPT_DEMO_IMAGE.

How the environment is made deterministic
-----------------------------------------
`demo.bash` defines functions for every external program the helper calls:
docker, podman, git, psql, mysql, redis-cli, make, systemctl, timedatectl,
locale, toe, findmnt and ps. `ls` and `find` are wrapped only for the two
paths the helper probes (/sys/class/net and /dev); every other call is
delegated to the real command. A `compgen` wrapper answers only the
user/group/variable/command/hostname queries and delegates -f/-d/-W to the
builtin, so file completion still works normally.

Everything that used to be a fixture is generated while building the image:
the Makefile, Dockerfile, app.dockerfile, config/key/cert/log files, empty
pkg.tar.gz and pkg.zip archives, the output directory, /etc/shells and
~/.ssh/config. Nothing stateful or host-specific is committed.

What is asserted
----------------
verify.bash covers every argtype: Docker and Podman images/containers/
volumes/networks/contexts/services, git branches/commits/remotes/tags/
tracked files/stashes/worktrees, database users and names, Redis keys,
Makefile targets, environment variables, systemd units, users and groups,
hosts, commands, PIDs, interfaces, devices, mounts, timezones, locales,
shells, terminal types, key/cert/log/archive files, FILE and DIR fallbacks,
choice lists (`--mode=debug|info|warn`), and the repeatability rules:

  * at least one `..`/`...` marker in the help enables smart mode;
  * unmarked options are hidden once used;
  * marked options stay available;
  * a help without any marker keeps offering every option.

`tool` already carries every marker variant (`--include=<FILE>...`,
`--verbose...`, `--define=<KEY=VALUE>..`, plus unmarked `--exclude` and
`--quiet`), so the only extra tool is `plain`, which has no markers at all.
That is the safe fallback: if the help does not document repetition, nothing
is hidden. `[OPTIONS]...` in a usage line and `--opt <FILE>...` (space
separated) are also not treated as markers.

Extending
---------
Add an option line to `tool()` in demo.bash, add or extend the matching fake
function, and add an assertion to verify.bash. No state or cleanup is needed:
the fakes have none.
