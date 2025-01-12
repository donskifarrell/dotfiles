{
  inputs,
  pkgs,
  ...
}:
let
  vscode-marketplace = inputs.nix-vscode-extensions.extensions.${system}.vscode-marketplace;

  # TODO: Move to a top-level config
  system = "${if pkgs.stdenv.isDarwin then "aarch64-darwin" else "x86_64-linux"}";
in
{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;

    extensions = with vscode-marketplace; [
      astro-build.astro-vscode
      bradlc.vscode-tailwindcss
      dbaeumer.vscode-eslint
      donjayamanne.githistory
      esbenp.prettier-vscode
      formulahendry.auto-close-tag
      formulahendry.auto-rename-tag
      foxundermoon.shell-format
      golang.go
      jetpack-io.devbox
      jgclark.vscode-todo-highlight
      jnoortheen.nix-ide
      jock.svg
      matthewpi.caddyfile-support
      mkhl.direnv
      ms-vscode-remote.remote-ssh
      redhat.vscode-yaml
      streetsidesoftware.code-spell-checker
      tamasfe.even-better-toml
      waderyan.gitblame
    ];
  };
}
