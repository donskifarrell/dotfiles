#!/bin/sh

# Note: needs to be correct for PNPM global to work
export NODE="/usr/local/Cellar/node/14.5.0"
export PNPM_STORE="/Users/donski/.pnpm-store/v3"

export PATH="$PATH:${PNPM_STORE}/:${NODE}/"
