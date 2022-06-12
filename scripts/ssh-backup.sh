#!/bin/bash

set -e

echo "Backup of ~/.ssh folder with Age"
while getopts 'h:' OPTION; do
    case "$OPTION" in
    h)
        HOSTNAME="$OPTARG"
        echo "Hostname: $HOSTNAME"
        ;;
    ?)
        echo "script usage: $(basename \$0) [-h <machine-hostname>]" >&2
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

echo "!!!"
echo "    SAVE THE PASSPHRASE"
echo "!!!"
echo ""
echo "Press Enter to continue"
read -r

DATE=$(date '+%Y-%m-%d')

cd ~/.ssh
tar czvf ./ssh-$HOSTNAME-$DATE.tar.gz --exclude config .
age -p ./ssh-$HOSTNAME-$DATE.tar.gz > ~/.dotfiles/secrets/ssh-$HOSTNAME-$DATE.tar.gz.age
rm -v ./ssh-$HOSTNAME-$DATE.tar.gz
cd -
echo "Backup of ~/.ssh to ~/.dotfiles/secrets/ssh-$HOSTNAME-$DATE.tar.gz.age complete"

echo "Done. Press Enter"

read -r
