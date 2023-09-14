#!/bin/bash

set -e

echo "Restore Age file to ~/.ssh folder"
while getopts 'f:' OPTION; do
    case "$OPTION" in
    f)
        AGEFILEPATH="$OPTARG"
        echo "Age file path: $AGEFILEPATH"
        ;;
    ?)
        echo "script usage: $(basename \$0) [-f <age-filepath>]" >&2
        exit 1
        ;;
    esac
done
shift "$(($OPTIND - 1))"

echo "Press Enter to continue"
read -r

mkdir -p ~/.ssh
cd ~/.ssh

FILENAME=$(basename ${AGEFILEPATH})
TARFILE=${FILENAME::-4}
echo "Tar file name: $TARFILE"

age -d $AGEFILEPATH >$TARFILE
tar xvf $TARFILE
rm -v $TARFILE

cd -
echo "Restore of ~/.ssh from $AGEFILEPATH complete"

# echo "Set permissions on .SSH folder"
# sudo chmod 600 ~/.ssh/*
# sudo chmod 644 ~/.ssh/known_hosts
# sudo chmod 755 ~/.ssh

echo ""
echo "You'll likely want to run 'ssh-add --apple-use-keychain ~/.ssh/[your-private-key]' for each of the keys you need."
echo "Also update the ~/.ssh/sshconfig.local file too"
echo ""
echo "Done. Press Enter"

read -r
