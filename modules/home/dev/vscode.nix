{ inputs, ... }:
{
  config.flake.homeModules.vscode =
    {
      config,
      pkgs,
      ...
    }:
    let
      vscode-marketplace =
        inputs.nix-vscode-extensions.extensions.${pkgs.stdenv.hostPlatform.system}.vscode-marketplace;
    in
    {
      config = {
        # This is to ensure no matter how vscode launches (via desktop of terminal) it uses the same env.
        home.packages = [
          (pkgs.writeShellScriptBin "code-login" ''
            exec ${pkgs.fish}/bin/fish -lc 'code --reuse-window $argv'  
          '')
        ];
        xdg.desktopEntries.code = {
          name = "Visual Studio Code";
          genericName = "Code Editor";
          exec = "code-login %F";
          icon = "code";
          terminal = false;
          categories = [
            "Development"
            "IDE"
          ];
        };

        programs.vscode = {
          enable = true;
          mutableExtensionsDir = true;

          profiles.default = {
            extensions = with vscode-marketplace; [
              astro-build.astro-vscode
              bradlc.vscode-tailwindcss
              bufbuild.vscode-buf
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
              redhat.vscode-yaml
              saoudrizwan.claude-dev
              streetsidesoftware.code-spell-checker
              tamasfe.even-better-toml
              waderyan.gitblame

              # AllowUnfree hack
              (ms-windows-ai-studio.windows-ai-studio.override { meta.license = [ ]; })
              # ms-vscode-remote.remote-ssh
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
                "[css]": {
                  "editor.defaultFormatter": "esbenp.prettier-vscode"
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
                "[xml]": {
                  "editor.defaultFormatter": "redhat.vscode-xml",
                  "editor.tabSize": 2
                },
                "[github-actions-workflow]": {
                  "editor.defaultFormatter": "redhat.vscode-yaml"
                },
                "go.formatTool": "gofmt",
                "go.toolsManagement.autoUpdate": false,
                "go.lintTool": "golangci-lint",
                "go.lintOnSave": "package",
                "go.lintFlags": [
                ],
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
                "git.path": "/run/current-system/sw/bin/git",
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
                "remote.SSH.configFile": "${config.home.homeDirectory}/.ssh/sshconfig.local",
                "Prettier-SQL.SQLFlavourOverride": "mysql",
                "Prettier-SQL.expressionWidth": 120,
                "terminal.integrated.inheritEnv": true,
                "terminal.integrated.defaultProfile.linux": "fish"
              }
            '';
          };
        };
      };
    };
}
