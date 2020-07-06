#!/bin/sh
# setups the auto-update

# I've disabled this for now as the fix for `crontab: tmp/tmp.99366: Operation not permitted` is giving terminal full disk access - no.
#

# (
# 	crontab -l | grep -v "dot_update"
# 	echo "0 */2 * * * $HOME/.dotfiles/bin/dot_update > ${TMPDIR:-/tmp}/dot_update.log 2>&1"
# ) | crontab -
