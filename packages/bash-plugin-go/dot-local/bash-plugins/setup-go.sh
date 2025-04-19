#!/bin/bash
# Golang
export GOROOT="$LOCAL/go"
export GOPATH="$GOROOT/bin"
if [ -d "$GOPATH" ]; then
    export PATH="$GOPATH:$GOPATH/bin:$PATH"
else
    setup-go-linux-amd64() {
        wget -O - -o /dev/null https://go.dev/dl/go1.22.5.linux-amd64.tar.gz | tar -C "$LOCAL" -xzvf -
    }
fi
