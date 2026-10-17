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
      Deterministic root options from `fakectl --help`.

  fakectl container stop --<Tab>
      Deterministic options from `fakectl container stop --help`.

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
      Context still runs, but `fakectl container stop web --help` must not.

  fakectl image rm some-image <Tab>
      Context still runs, but help is denied by the ordered image rules.

Help rules for images
---------------------
The config uses:

  --allow-help 'fakectl image*'
  --deny-help  'fakectl image rm*'
  --allow-help 'fakectl image rm'

Last matching rule wins:

  fakectl image rm          -> allowed
  fakectl image rm target   -> denied
  fakectl image list        -> allowed

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
fakectl has no built-in completion, so `efficient` falls through to the help
and model stages. `efficient`, `llm-first`, `merge`, and `override` therefore
reach the same path for this fixture.
