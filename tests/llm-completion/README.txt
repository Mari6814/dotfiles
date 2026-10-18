llm_complete interactive test setup
===================================

Purpose
-------
Test how llm_complete behaves using a fake container CLI with fake help and
state. There are no real containers, downloads, Docker/Ollama calls, or tmux
commands in the completion targets.

Files
-----
  fixtures/fakectl    fake container CLI and state machine
  fakectl.bash        sourceable llm_complete configuration for fakectl
  run.bash            opens a two-pane tmux session: shell + log tail

Quick start
-----------
  ./tests/llm-completion/run.bash

If you are already inside tmux it switches to `llm-completion-test`; from a
normal shell it starts tmux and attaches. If the session is already running,
the script switches to it without resetting state. Use --restart to recreate
the session, reset the fake state, and clear the log:

  ./tests/llm-completion/run.bash --restart

The left pane is ready at:

  llm-test$

The right pane follows:

  /tmp/llm-completion.log

Manual setup
------------
  source tests/llm-completion/fakectl.bash
  fakectl reset
  export LLM_COMPLETE_LOGFILE=/tmp/llm-completion.log

The fake state is stored under:

  ${TMPDIR:-/tmp}/llm-completion-test/

Reset it at any time:

  fakectl reset

Test cases
----------
  fakectl --<Tab>
      No previous completion exists, so the LLM path runs with
      `fakectl --help` as context.

  fakectl container <Tab>
      LLM path with `fakectl container --help` as context.

  fakectl container stop --<Tab>
      LLM path with `fakectl container stop --help` as context.

  fakectl container stop <Tab>
      Runs `fakectl container ps --quiet` as context and asks the model for a
      running container.

  fakectl container start <Tab>
      Runs `fakectl container ps -a -f state=stopped --quiet` as context.

  fakectl container run <Tab>
      Runs `fakectl image list --quiet` as context.

  fakectl container inspect <Tab>
      Runs `fakectl container ps -a --quiet` as context.

  fakectl image rm <Tab>
      Runs `fakectl image list --quiet` as context.

  fakectl container stop web <Tab>
      Context still runs, and help falls back to
      `fakectl container stop --help`.

  fakectl image rm some-image <Tab>
      Context still runs, and help falls back to
      `fakectl image rm --help`.

Help rules
----------
Help paths are relative to the registered command. Patterns are prefix
matches; `*` matches any path, and a trailing `*` requires at least one more
path segment.

The config uses:

  --allow-help '*'
  --deny-help  'container stop *'
  --deny-help  'image rm *'

Last matching rule wins, and help resolves to the nearest allowed ancestor:

  fakectl container stop web     -> help target container stop
  fakectl image rm target        -> help target image rm
  fakectl image rm               -> help target image rm
  fakectl image list             -> help target image list
  fakectl                        -> help target root

So `fakectl image rm <Tab>` runs:

  fakectl image rm --help

`fakectl image rm some-image <Tab>` also runs:

  fakectl image rm --help

The target argument is never passed into `--help`.

Pattern notes:

  --allow-help ''        root help everywhere, like _longopt
  --allow-help '*'       path help everywhere
  --deny-help 'image rm *'  reject only deeper paths; bare image rm still has help
  --deny-help 'image rm'    reject image rm and deeper; fall back to image help

Paths ignore options and assignments. The path extractor is intentionally
simple: a separate option value that is not an option may appear as a path
segment.

State transitions
-----------------
Initial state:

  image   nginx:latest, alpine:latest
  container web   nginx:latest  running
  container db    alpine:latest stopped

Try:

  fakectl container stop web
  fakectl container start <Tab>     # web now appears as stopped

  fakectl container start web
  fakectl container stop <Tab>      # web now appears as running

  fakectl container run --name app --publish 9090:80 nginx:latest
  fakectl container stop <Tab>      # app and web

  fakectl container stop app
  fakectl container rm app

  fakectl container rm web          # fails while running
  fakectl container rm --force web

Dynamic context
---------------
There is no reply cache. Change the fake state between tabs and the next
completion sees the new state:

  fakectl container stop web
  fakectl container start <Tab>     # web appears
  fakectl container start web
  fakectl container stop <Tab>      # web is gone

Log
---
The run.bash session enables the log in the left pane. To inspect the prompt,
help, context, model response, and final candidates:

  tail -n 200 /tmp/llm-completion.log

Look for:

  original func=... mode=efficient
  help allowed base=fakectl\ container\ stop cmd=...
  context cmd=fakectl\ container\ ps
  === ... MODEL ===
  --- prompt ---
  --- response ---
  --- candidates ---

Mode note
---------
fakectl has no built-in completion, so `efficient` falls through to the model
path. `efficient`, `llm-first`, `merge`, and `override` therefore reach the
same path for this fixture.
