# dotfiles

Forked from https://github.com/caarlos0/dotfiles

### Stack:

- ZSH: https://sourceforge.net/p/zsh/code/ci/master/tree/
- Antibody: https://github.com/getantibody/antibody
- Starship: https://starship.rs/
- Alacritty: https://github.com/alacritty/alacritty
  - Dracula theme: https://draculatheme.com/alacritty
- TMUX
  - Modified Dracula theme: https://draculatheme.com/tmux
- Hack font: https://sourcefoundry.org/hack/

TODO:

- Add brew files
- Push commits up
- set better project home
- remove branks golang setting
- tmux statusbar
  - CPU & MEM
- double click to highlight text - hold [shift]
- click links - [shift][ctrl] - click
- write out all the keybindings
  - Alacritty
  - ZSH
    - fzf
    - gitfzf
    - ?
  - TMux
    - tabs
    - zoom
    - select/copy text
  - Rectangle

## Installation

### Dependencies

First, make sure you have all those things installed:

- `git`: to clone the repo
- `curl`: to download some stuff
- `tar`: to extract downloaded stuff
- `zsh`: to actually run the dotfiles - zsh 5.8
- `sudo`: some configs may need that
- `brew`: https://brew.sh/

### Install

Then, run these steps:

```console
$ git clone git@github.com:donskifarrell/dotfiles.git ~/.dotfiles
$ cd ~/.dotfiles
$ ./script/bootstrap
$ zsh # or just close and open your terminal again.
```

> All changed files will be backed up with a `.backup` suffix.

### macOS defaults

You use it by running:

```console
$DOTFILES/macos/set-defaults.sh
```

And logging out and in again/restart.

# Naming conventions

There are a few special files in the hierarchy:

- **bin/**: Anything in `bin/` will get added to your `$PATH` and be made
  available everywhere.
- **topic/\*.zsh**: Any files ending in `.zsh` get loaded into your
  environment.
- **topic/path.zsh**: Any file named `path.zsh` is loaded first and is
  expected to setup `$PATH` or similar.
- **topic/completion.zsh**: Any file named `completion.zsh` is loaded
  last and is expected to setup autocomplete.
- **topic/\*.symlink**: Any files ending in `*.symlink` get symlinked into
  your `$HOME`. This is so you can keep all of those versioned in your dotfiles
  but still keep those autoloaded files in your home directory. These get
  symlinked in when you run `script/bootstrap`.
- **topic/install.sh**: Any file with this name and with exec permission, will
  ran at `bootstrap` and `dot_update` phase, and are expected to install plugins,
  and stuff like that.

# Personalization

> How to add custom configuration without messing the local repository

## For the shell itself

You can add anything you want (secret stuff, for example), to the `~/.localrc`
file.

## For git

You can just change the default `~/.gitconfig` file, since it includes the
dotfiles managed one.

## For psql

You can edit the `~/.psqlrc.local` file.

## For ssh

You can edit the `~/.ssh/config.local` file.

## Default `EDITOR`, `VEDITOR` and `PROJECTS`

`VEDITOR` stands for "visual editor", and is set to `code` be default. `EDITOR`
is set to `vim`.

`PROJECTS` is default to `~/Code`. The shortcut to that folder in the shell
is `c`.

You can change that by adding your custom overrides in `~/.localrc`.
