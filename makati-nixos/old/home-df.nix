{
  config,
  pkgs,
  lib,
  system,
  hostname,
  homepath,
  ...
}: {
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello
    age
    alejandra
    cht-sh
    ffmpeg
    git-filter-repo
    go
    gopls
    kubectl
    kubectx
    mkcert
    netperf
    nodejs
    nodePackages_latest.pnpm
    rlwrap
    shfmt
    wmctrl
    lsof
    android-tools
    python311
    python311Packages.pip
    bash
    gnome.zenity
    quickemu
    dconf2nix
    bash
    coreutils
    gawk
    micro
    wget
    curl
    git
    htop
    bat
    fzf
    fd
    ripgrep
    jq
    fx
    unzip
    htop
    bat
    exa
    fzf
    fd
    ripgrep
    jq
    fx
    unzip
    opensnitch-ui
    brave
    chromium
    vivaldi
    firefox
    maestral-gui
    _1password-gui
    gimp
    vlc
    spotify
    mattermost-desktop
    obsidian
    sublime4
    vscode
    hunspell
    libreoffice-still
    ulauncher
    gnome-extension-manager
    gnomeExtensions.dash-to-dock
    gnomeExtensions.gsconnect
    gnomeExtensions.mpris-indicator-button
    gnomeExtensions.caffeine
    gnomeExtensions.vitals
    gnomeExtensions.just-perfection
    gnomeExtensions.sound-output-device-chooser
    gnomeExtensions.blur-my-shell
    gnomeExtensions.appindicator
    gnomeExtensions.gtile
    gnomeExtensions.allow-locked-remote-desktop
    spice-gtk
    spice

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })
    (google-cloud-sdk.withExtraComponents [google-cloud-sdk.components.gke-gcloud-auth-plugin])
    (nerdfonts.override {fonts = ["JetBrainsMono"];})

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  home.activation = {
    enableULauncher = ''
      /run/current-system/sw/bin/systemctl --user enable --now ulauncher
    '';
  };

  home.file = let
    autostartPrograms = [pkgs._1password-gui];
  in
    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    builtins.listToAttrs (map
      (pkg: {
        name = ".config/autostart/" + pkg.pname + ".desktop";
        value =
          if pkg ? desktopItem
          then {
            # Application has a desktopItem entry.
            # Assume that it was made with makeDesktopEntry, which exposes a
            # text attribute with the contents of the .desktop file
            text = pkg.desktopItem.text;
          }
          else {
            # Application does *not* have a desktopItem entry. Try to find a
            # matching .desktop name in /share/apaplications
            source = pkg + "/share/applications/" + pkg.pname + ".desktop";
          };
      })
      autostartPrograms);

  # # Building this configuration will create a copy of 'dotfiles/screenrc' in
  # # the Nix store. Activating the configuration will then make '~/.screenrc' a
  # # symlink to the Nix store copy.
  # ".screenrc".source = dotfiles/screenrc;

  # # You can also set the file content immediately.
  # ".gradle/gradle.properties".text = ''
  #   org.gradle.console=verbose
  #   org.gradle.daemon.idletimeout=3600000
  # '';
  #  home.file = {
  # ...
  #  };

  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;

    extensions = with pkgs; [
      vscode-extensions.golang.go
      vscode-extensions.kamadorueda.alejandra
      vscode-extensions.bbenoist.nix
      vscode-extensions.formulahendry.auto-close-tag
      vscode-extensions.formulahendry.auto-rename-tag
      vscode-extensions.tamasfe.even-better-toml
      vscode-extensions.dracula-theme.theme-dracula
      vscode-extensions.dbaeumer.vscode-eslint
      vscode-extensions.hashicorp.terraform
      vscode-extensions.esbenp.prettier-vscode
      vscode-extensions.ms-vscode-remote.remote-ssh
      vscode-extensions.foxundermoon.shell-format
      vscode-extensions.bradlc.vscode-tailwindcss
      vscode-extensions.redhat.vscode-yaml
      vscode-extensions.streetsidesoftware.code-spell-checker
      vscode-extensions.donjayamanne.githistory
      vscode-extensions.jock.svg

      # Not on nixpkgs yet:
      # vscode-extensions.wayou.vscode-todo-highlight
      # vscode-extensions.vscode-icons-team.vscode-icons
      # vscode-extensions.waderyan.gitblame
    ];

    userSettings = {
      "alejandra.program" = "alejandra";
      "diffEditor.ignoreTrimWhitespace" = false;
      "editor.wordWrap" = "on";
      "editor.linkedEditing" = true;
      "editor.formatOnSave" = true;
      "editor.bracketPairColorization.enabled" = true;
      "editor.unicodeHighlight.includeStrings" = false;
      "editor.tabSize" = 2;
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
      "workbench.iconTheme" = "vscode-icons";
      "workbench.colorTheme" = "Dracula";
      "[nix]"."editor.defaultFormatter" = "kamadorueda.alejandra";
      "[nix]"."editor.formatOnPaste" = true;
      "[nix]"."editor.formatOnSave" = true;
      "[nix]"."editor.formatOnType" = false;
      "[typescript]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
      "[typescriptreact]"."editor.defaultFormatter" = "esbenp.prettier-vscode";
      "shellformat.path" = "${homepath}/.nix-profile/bin/shfmt";
      "remote.SSH.configFile" = "${homepath}/.ssh/sshconfig.local";
      "[dockerfile]"."editor.defaultFormatter" = "ms-azuretools.vscode-docker";
      "files"."associations"."*.tmpl" = "html";
    };
  };
}
