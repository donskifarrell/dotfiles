{
  pkgs,
  inputs,
  lib,
  user,
  system,
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
          "[typescript]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },
          "[typescriptreact]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },
            "editor.wordWrap": "on",
            "editor.linkedEditing": true,
            "editor.formatOnSave": true,
            "editor.bracketPairColorization.enabled": true,
            "editor.unicodeHighlight": {
              "includeStrings": false
            },
            "editor.tabSize": 2,
            "editor.fontLigatures": true,
            "editor.fontFamily": "JetBrainsMono Nerd Font, 'Droid Sans Mono', 'monospace', monospace",
          "alejandra.program": "alejandra",
          "diffEditor.ignoreTrimWhitespace": false,
          "explorer.confirmDelete": false,
          "files": {
            "trimTrailingWhitespace": true,
            "insertFinalNewline": true,
            "encoding": "utf8",
            "eol": "\n",
            "associations": {
              "*.tmpl": "html"
            }
          },
          "git.confirmSync": false,
          "go": {
            "toolsManagement": {
              "autoUpdate": true
            },
            "formatTool": "gofmt"
          },
          "html.format.enable": false,
          "redhat.telemetry.enabled": false,
          "remote.SSH.configFile": "/home/df/.ssh/sshconfig.local",
          "shellformat.path": "/etc/profiles/per-user/df/bin/shfmt",
          "vetur.format.defaultFormatter.html": "none",
          "workbench": {
            "iconTheme": "catppuccin-macchiato",
            "colorTheme": "Catppuccin Macchiato"
          }
        }
      ''
      // {
        "shellformat.path" = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/etc/profiles/per-user/${user}/bin/shfmt")
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.nix-profile/bin/shfmt")
        ];
        "remote.SSH.configFile" = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${user}/.ssh/sshconfig.local")
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.ssh/sshconfig.local")
        ];
      };
  };
}
