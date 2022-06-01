#!/bin/bash

set -e

echo "Setup home-manager on OSX. Press Enter"
while getopts 'h:u:' OPTION; do
    case "$OPTION" in
    h)
        HOSTNAME="$OPTARG"
        echo "Hostname: $HOSTNAME"
        ;;
    u)
        USERNAME="$OPTARG"
        echo "Username: $USERNAME"
        ;;
    ?)
        echo "script usage: $(basename \$0) [-h <machine-hostname>] [-u <home-username>]" >&2
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

read -r
