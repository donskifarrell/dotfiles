# My dotfiles

Forked from https://github.com/caarlos0/dotfiles

TODO:

- Add brew files
- Push commits up
- remove branks golang setting
- tmux statusbar

Issues:

- set better project home
- mouse copy/paste
- opt-arrow jump words
- auto-suggest annoying?

zcompdump keeps loading..

[![Powered by Antibody][ab]][ap]

> Config files for ZSH, Java, Ruby, Go, Editors, Terminals and more.

[ap]: https://github.com/getantibody/antibody

## Installation

### Dependencies

First, make sure you have all those things installed:

- `git`: to clone the repo
- `curl`: to download some stuff
- `tar`: to extract downloaded stuff
- `zsh`: to actually run the dotfiles
- `sudo`: some configs may need that

### Install

Then, run these steps:

```console
$ git clone git@github.com:donskifarrell/dotfiles.git ~/.dotfiles
$ cd ~/.dotfiles
$ ./script/bootstrap
$ zsh # or just close and open your terminal again.
```

> All changed files will be backed up with a `.backup` suffix.

### Recommended Software

For macOS, I recommend:

- iTerm: a better terminal emulator;

For both Linux and macOS:

- [`diff-so-fancy`](https://github.com/so-fancy/diff-so-fancy):
  better git diffs (you'll need to run `dot_update` to apply it);
- [`fzf`](https://github.com/junegunn/fzf):
  fuzzy finder, used in `,t` on vim, for example;
- [`kubectx`](https://github.com/ahmetb/kubectx) for better kubernetes context
  and namespace switch;

### macOS defaults

You use it by running:

```console
$DOTFILES/macos/set-defaults.sh
```

And logging out and in again/restart.

### Themes and fonts being used

Theme is **[Dracula](https://draculatheme.com)**, font is **JetBrains Mono** on
editors and **Hack** on terminals.

## Further help:

- [Personalize your configs](/docs/PERSONALIZATION.md)
- [Understand how it works](/docs/PHILOSOPHY.md)
- [License](/LICENSE.md)

## Contributing

Feel free to contribute. Pull requests will be automatically
checked/linted with [Shellcheck](https://github.com/koalaman/shellcheck)
and [shfmt](https://github.com/mvdan/sh).
