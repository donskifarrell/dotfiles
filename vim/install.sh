#!/bin/sh

echo "›› ignoring basic VIM"
# curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
# 	https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Assume `brew install vim`
# echo "›› with VIM"
# /usr/local/bin/vim +'PlugInstall --sync' +qa
# /usr/local/bin/vim +'PlugUpdate' +qa

if command -v nvim >/dev/null 2>&1; then
	echo "›› with NVIM"
	curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

	mkdir -p ~/.config/nvim/
	ln -sf "$DOTFILES/vim/vimrc.symlink" ~/.config/nvim/init.vim
	ln -sf "$DOTFILES/vim/en.utf-8.add" ~/.config/nvim/en.utf-8.add
	nvim +'PlugInstall --sync' +qa
	nvim +'PlugUpdate' +qa
fi
