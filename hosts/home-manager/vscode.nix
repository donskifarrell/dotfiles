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
      jetpack-io.devbox
      jgclark.vscode-todo-highlight
      jnoortheen.nix-ide
      jock.svg
      kamadorueda.alejandra
      matthewpi.caddyfile-support
      mkhl.direnv
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
            "editor.formatOnType": false
          },
          "nix.enableLanguageServer": true,
          "nix.serverPath": "nil",
          "nix.serverSettings": {
            "nil": {
              "formatting": {
                "command": [
                  "alejandra"
                ]
              }
            }
          },
          "[typescript]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },
          "[typescriptreact]": {
            "editor.defaultFormatter": "esbenp.prettier-vscode"
          },
          "go.formatTool": "gofmt",
          "go.toolsManagement.autoUpdate": true,
          "alejandra.program": "alejandra",
          "cSpell.language": "en-GB",
          "diffEditor.ignoreTrimWhitespace": false,
          "editor.bracketPairColorization.enabled": true,
          "editor.fontFamily": "JetBrainsMono Nerd Font, 'Droid Sans Mono', 'monospace', monospace",
          "editor.fontLigatures": true,
          "editor.formatOnSave": true,
          "editor.linkedEditing": true,
          "editor.tabSize": 2,
          "editor.wordWrap": "on",
          "editor.unicodeHighlight.includeStrings": true,
          "explorer.confirmDelete": false,
          "files.trimFinalNewlines": true,
          "files.trimTrailingWhitespace": true,
          "files.eol": "\n",
          "files.encoding": "utf8",
          "files.associations": {
            "*.tmpl": "html"
          },
          "git.confirmSync": false,
          "html.format.enable": false,
          "redhat.telemetry.enabled": false,
          "workbench.iconTheme": "catppuccin-macchiato",
          "workbench.colorTheme": "Catppuccin Macchiato",
          "todohighlight.keywords": [
            {
              "text": "TODO:",
              "color": "#fff",
              "backgroundColor": "#ffbd2a",
              "overviewRulerColor": "rgba(255,189,42,0.8)"
            },
            {
              "text": "TODO",
              "color": "#fff",
              "backgroundColor": "#ffbd2a",
              "overviewRulerColor": "rgba(255,189,42,0.8)"
            },
            {
              "text": "[TODO]",
              "color": "#fff",
              "backgroundColor": "#ffbd2a",
              "overviewRulerColor": "rgba(255,189,42,0.8)"
            },
            {
              "text": "FIXME:",
              "color": "#fff",
              "backgroundColor": "#f06292",
              "overviewRulerColor": "rgba(240,98,146,0.8)"
            }
          ],
          "todohighlight.include": [
            "**/*.js",
            "**/*.jsx",
            "**/*.ts",
            "**/*.tsx",
            "**/*.html",
            "**/*.css",
            "**/*.scss",
            "**/*.php",
            "**/*.rb",
            "**/*.txt",
            "**/*.mdown",
            "**/*.md",
            "**/*.go",
            "**/*.tmpl",
            "**/*.sql"
          ],
          "caddyfile.executable": "${config.home.homeDirectory}/dev/mono/.devbox/virtenv/.wrappers/bin/caddy",
          "remote.SSH.configFile": "${config.home.homeDirectory}/.ssh/sshconfig.local",
          "shellformat.path": "${config.home.homeDirectory}/.nix-profile/bin/shfmt",
          "Prettier-SQL.SQLFlavourOverride": "postgresql"
        }
      ''
      // {
        "window.zoomLevel" = lib.mkMerge [
          (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 1)
          (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 0)
        ];
      };
  };
}
