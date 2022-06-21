#!/bin/bash

set -e

echo "Backup of ~/.local folder with Age"
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

cd ~/.local
tar czvf ./local-config-$HOSTNAME-$DATE.tar.gz --exclude share .
age -p ./local-config-$HOSTNAME-$DATE.tar.gz > ~/.dotfiles/secrets/local-config-$HOSTNAME-$DATE.tar.gz.age
rm -v ./local-config-$HOSTNAME-$DATE.tar.gz
cd -
echo "Backup of ~/.local to ~/.dotfiles/secrets/local-config-$HOSTNAME-$DATE.tar.gz.age complete"

echo "Done. Press Enter"

read -r
