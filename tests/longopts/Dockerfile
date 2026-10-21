# Longopts demo image. Build from the repository root:
#   docker build -f tests/longopts/Dockerfile -t longopts-demo .
#
# Only bash, bash-completion and awk are installed. Every external tool the
# completion helper asks about (docker, podman, git, psql, ...) is a fake
# function defined in demo.bash.
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash bash-completion gawk \
    && rm -rf /var/lib/apt/lists/*

COPY packages/completions/*/bash-completion/helpers/better_longopt.bash /demo/better_longopt.bash
COPY tests/longopts/demo.bash /demo/demo.bash
COPY tests/longopts/verify.bash /demo/verify.bash

# Filesystem fixtures are generated here instead of being committed: an empty
# Makefile, Dockerfiles, config/key/cert/log files, archives and a directory.
RUN mkdir -p /demo/work/src /demo/work/outdir \
    && cd /demo/work \
    && touch Makefile Dockerfile app.dockerfile app.conf notes.txt \
             id_demo id_demo.pub demo.asc \
             server.crt ca.cer ca.cert ca.pem \
             app.log pkg.tar.gz pkg.zip src/main.c

# Deterministic LOGIN_SHELL and HOST sources.
RUN printf '/bin/sh\n/bin/bash\n' > /etc/shells \
    && mkdir -p /demo/home/.ssh \
    && printf '%s\n' \
        'Host demo-host' \
        '  HostName 192.0.2.10' \
        '' \
        'Host demo-alt' \
        '  HostName 192.0.2.11' \
        > /demo/home/.ssh/config \
    && chmod 600 /demo/home/.ssh/config

ENV HOME=/demo/home
WORKDIR /demo/work

CMD ["bash", "/demo/verify.bash"]
