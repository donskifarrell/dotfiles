#!/bin/sh
export GOPATH="$HOME/.go"

test -d "${GOPATH}" || mkdir "${GOPATH}"
test -d "${GOPATH}/src" || mkdir -p "${GOPATH}/src"
test -d "${GOPATH}/pkg" || mkdir -p "${GOPATH}/pkg"
test -d "${GOPATH}/bin" || mkdir -p "${GOPATH}/bin"

test -d "${GOPATH}/src/github.com" || mkdir -p "${GOPATH}/src/github.com"
