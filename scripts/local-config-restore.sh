#!/bin/bash

set -e

echo "Restore Age file to ~/.local folder"
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

mkdir -p ~/.local
cd ~/.local

FILENAME=$(basename ${AGEFILEPATH})
TARFILE=${FILENAME::-4}
echo "Tar file name: $TARFILE"

age -d $AGEFILEPATH > $TARFILE
tar xvf $TARFILE
rm -v $TARFILE

cd -
echo "Restore of ~/.local from $AGEFILEPATH complete"

echo "Done. Press Enter"

read -r
