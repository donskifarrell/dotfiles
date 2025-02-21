{
  config,
  inputs,
  pkgs,
  ...
}:
let
  vscode-marketplace = inputs.nix-vscode-extensions.extensions.${system}.vscode-marketplace;
  homeDir = config.me.homeDir;
  system = config.me.system;
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
      inferrinizzard.prettier-sql-vscode
      jetpack-io.devbox
      jgclark.vscode-todo-highlight
      jnoortheen.nix-ide
      jock.svg
      matthewpi.caddyfile-support
      mechatroner.rainbow-csv
      mkhl.direnv
      ms-vscode-remote.remote-ssh
      redhat.vscode-yaml
      streetsidesoftware.code-spell-checker
      tamasfe.even-better-toml
      waderyan.gitblame
    ];

    userSettings = builtins.fromJSON ''
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
        "nix.formatterPath": "nixfmt",
        "[nix]": {
          "editor.defaultFormatter": "jnoortheen.nix-ide"
        },
        "[typescript]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[typescriptreact]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "go.formatTool": "gofmt",
        "go.toolsManagement.autoUpdate": false,
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
        "redhat.telemetry.enabled": false,
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
        "remote.SSH.configFile": "${homeDir}/.ssh/sshconfig.local",
        "Prettier-SQL.SQLFlavourOverride": "mysql",
        "Prettier-SQL.expressionWidth": 120
      }
    '';
  };
}
