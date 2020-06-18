#!/bin/sh

echo "Running Nano installer"

# Install nano editor https://www.nano-editor.org/dist/v4/nano-4.9.3.tar.xz Modified: 2020 May 23 

VERSION="4.9.3"
NANO_SHORT="nano-$VERSION"
NANO_SRC="$NANO_SHORT.tar.xz"
NANO_URL="https://www.nano-editor.org/dist/v4"
NANO_EXTRA="https://github.com/scopatz/nanorc"

cd ~/
wget $NANO_URL/$NANO_SRC
tar -zxvf $NANO_SRC

mv $NANO_SHORT .nano && cd .nano/
mkdir backups
./configure && make && sudo make install

git clone --depth=1 $NANO_EXTRA "$HOME"/.nano/syntax_improved
# cd ~/ && touch .nanorc

rm -vf $NANO_SRC
print "\nEXit terminal and reopen using $NANO_SHORT\n"
exit
