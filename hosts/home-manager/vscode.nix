{
  pkgs,
  lib,
  user,
  ...
}: {
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;

    extensions = with pkgs.vscode-extensions; [
      golang.go
      kamadorueda.alejandra
      bbenoist.nix
      formulahendry.auto-close-tag
      formulahendry.auto-rename-tag
      tamasfe.even-better-toml
      dbaeumer.vscode-eslint
      hashicorp.terraform
      esbenp.prettier-vscode
      ms-vscode-remote.remote-ssh
      foxundermoon.shell-format
      bradlc.vscode-tailwindcss
      redhat.vscode-yaml
      streetsidesoftware.code-spell-checker
      donjayamanne.githistory
      jock.svg
      catppuccin.catppuccin-vsc

      # Not on nixpkgs yet:
      # wayou.vscode-todo-highlight
      # Catppuccin.catppuccin-vsc-icons
      # vscode-icons-team.vscode-icons
      # waderyan.gitblame
    ];

    userSettings = {
      "window.zoomLevel" = -2;
      "alejandra.program" = "alejandra";
      "diffEditor.ignoreTrimWhitespace" = false;
      "editor.wordWrap" = "on";
      "editor.linkedEditing" = true;
      "editor.formatOnSave" = true;
      "editor.bracketPairColorization.enabled" = true;
      "editor.unicodeHighlight.includeStrings" = false;
      "editor.tabSize" = 2;
      "editor.fontLigatures" = true;
      "editor.fontFamily" = "JetBrainsMono Nerd Font, 'Droid Sans Mono', 'monospace', monospace";
      "explorer.confirmDelete" = false;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;
      "files.encoding" = "utf8";
      "files.eol" = "\n";
      "git.confirmSync" = false;
      "go.toolsManagement.autoUpdate" = true;
      "go.formatTool" = "gofmt";
      "html.format.enable" = false;
      "[html]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
      "[json]"."editor.defaultFormatter" = "vscode.json-language-features";
      "redhat.telemetry.enabled" = false;
      "vetur.format.defaultFormatter.html" = "none";
      "workbench.iconTheme" = "catppuccin-macchiato";
      "workbench.colorTheme" = "Catppuccin Macchiato";
      "[nix]"."editor.defaultFormatter" = "kamadorueda.alejandra";
      "[nix]"."editor.formatOnPaste" = true;
      "[nix]"."editor.formatOnSave" = true;
      "[nix]"."editor.formatOnType" = false;
      "[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
      "[typescriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
      "shellformat.path" = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/etc/profiles/per-user/${user}/bin/shfmt")
        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.nix-profile/bin/shfmt")
      ];
      "remote.SSH.configFile" = lib.mkMerge [
        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${user}/.ssh/sshconfig.local")
        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${user}/.ssh/sshconfig.local")
      ];
      "[dockerfile]"."editor.defaultFormatter" = "ms-azuretools.vscode-docker";
      "files"."associations"."*.tmpl" = "html";
    };
  };
}
