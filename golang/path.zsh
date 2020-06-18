#!/bin/sh
export GOPATH="$HOME/.go"

# $(brew --prefix golang) takes ages
# export GOROOT="$(brew --prefix golang)/libexec"
export GOROOT="/usr/local/opt/go/libexec"

export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"

# TODO: Move to localrc
export GOPRIVATE=brank.as/*
export GONOPROXY='brank.as/*'
export GONOSUMDB='brank.as/*'