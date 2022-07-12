#!/bin/bash

set -e

echo "Backup of ~/.ssh folder with Age"
while getopts 'h:' OPTION; do
    case "$OPTION" in
    h)
        TARGET_HOSTNAME="$OPTARG"
        echo "Hostname: $TARGET_HOSTNAME"
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
tar czvf ./ssh-$TARGET_HOSTNAME-$DATE.tar.gz --exclude config .
age -p ./ssh-$TARGET_HOSTNAME-$DATE.tar.gz > ~/.dotfiles/secrets/ssh-$TARGET_HOSTNAME-$DATE.tar.gz.age
rm -v ./ssh-$TARGET_HOSTNAME-$DATE.tar.gz
cd -
echo "Backup of ~/.ssh to ~/.dotfiles/secrets/ssh-$TARGET_HOSTNAME-$DATE.tar.gz.age complete"

echo "Done. Press Enter"

read -r
