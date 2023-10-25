{
  config,
  inputs,
  lib,
  pkgs,
  system,
  user,
  ...
}: {
  programs.vscode = let
    vscode-marketplace = inputs.nix-vscode-extensions.extensions.${system}.vscode-marketplace;
  in {
    enable = true;
    mutableExtensionsDir = true;

    extensions = with vscode-marketplace; [
      bradlc.vscode-tailwindcss
      catppuccin.catppuccin-vsc
      catppuccin.catppuccin-vsc-icons
      dbaeumer.vscode-eslint
      donjayamanne.githistory
      esbenp.prettier-vscode
      formulahendry.auto-close-tag
      formulahendry.auto-rename-tag
      foxundermoon.shell-format
      golang.go
      hashicorp.terraform
      jgclark.vscode-todo-highlight
      jnoortheen.nix-ide
      jock.svg
      kamadorueda.alejandra
      ms-vscode-remote.remote-ssh
      redhat.vscode-yaml
      streetsidesoftware.code-spell-checker
      tamasfe.even-better-toml
      waderyan.gitblame
    ];

    userSettings =
      builtins.fromJSON ''
        {
          "[dockerfile]": {
            "editor.defaultFormatter": "ms-azuretools.vscode-docker"
          },
          "[html]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },
          "[json]": {
            "editor.defaultFormatter": "vscode.json-language-features"
          },
          "[nix]": {
            "editor.defaultFormatter": "kamadorueda.alejandra",
            "editor.formatOnPaste": true,
            "editor.formatOnSave": true,
            "editor.formatOnType": false,
            "enableLanguageServer": true
          },
          "[typescript]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },
          "[typescriptreact]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },
          "alejandra.program": "alejandra",
          "diffEditor.ignoreTrimWhitespace": false,
          "editor.bracketPairColorization.enabled": true,
          "editor.fontFamily": "JetBrainsMono Nerd Font, 'Droid Sans Mono', 'monospace', monospace",
          "editor.fontLigatures": true,
          "editor.formatOnSave": true,
          "editor.linkedEditing": true,
          "editor.tabSize": 2,
          "editor.unicodeHighlight": {
            "includeStrings": false
          },
          "editor.wordWrap": "on",
          "explorer.confirmDelete": false,
          "files": {
            "associations": {
              "*.tmpl": "html"
            },
            "encoding": "utf8",
            "eol": "\n",
            "insertFinalNewline": true,
            "trimTrailingWhitespace": true
          },
          "git.confirmSync": false,
          "go": {
            "formatTool": "gofmt",
            "toolsManagement": {
              "autoUpdate": true
            }
          },
          "html.format.enable": false,
          "nix": {
            "serverPath": "nil",
            "serverSettings": {
              "nil": {
                "formatting": {
                  "command": ["alejandra"]
                }
              }
            }
          },
          "redhat.telemetry.enabled": false,
          "remote.SSH.configFile": "${config.home.homeDirectory}/.ssh/sshconfig.local",
          "vetur.format.defaultFormatter.html": "none",
          "workbench": {
            "colorTheme": "Catppuccin Macchiato",
            "iconTheme": "catppuccin-macchiato"
          },
          "workbench.iconTheme": "catppuccin-macchiato"
        }
      ''
      // {
        "shellformat.path" = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/etc/profiles/per-user/${user}/bin/shfmt")
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.nix-profile/bin/shfmt")
        ];
        "window.zoomLevel" = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 1)
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 0)
        ];
      };
  };
}
