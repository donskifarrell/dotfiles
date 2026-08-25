# role-sandbox.* — the two sandbox tiers a `scoite` guest can be built from.
# `dev` includes `minimal`, so the closures nest and a launch only pays for
# what its type actually needs:
#
#   minimal  shell + git + the agent harness, with internet access and nothing
#            else — for "run this thing somewhere it can't touch my machine".
#   dev      (default) the working sandbox: python, node, headless chromium,
#            compilers/nix-ld, the full TUI shell + git stack, devenv/direnv,
#            herdr, and the paseo daemon on :6767. The guest's nix store
#            overlay and home are both persistent, so `nix profile install` /
#            `npm i -g` / `pip install --user` survive stop→start, and a project
#            that declares its own toolchain in devenv.nix/flake.nix has it
#            pre-built at boot (scoite-workspace-init in
#            virtualisation/microvm-guest.nix).
#
# Collapsed from four tiers (minimal/generic/devenv/workstation) on 2026-08-24
# — TASKS.md S3. The middle two were never chosen deliberately: `devenv` was
# the default and got used for everything, `generic` and `workstation` only
# existed as the rungs on either side of it.
#
# One tier per Den host in modules/den/hosts/scoite.nix; the CLI's `--type`
# picks which. See docs/microvm-sandbox.md.
{ den, ... }:
{
  # --- minimal ---------------------------------------------------------
  # roles.default already carries `shell` + shell.bundles.base, so this is
  # only the delta: an interactive fish, git, and the agent tools.
  den.aspects.roles.sandbox.minimal.includes = with den.aspects; [
    shell.fish
    shell.starship
    dev.git
    apps.ai-tools
  ];

  # --- dev -------------------------------------------------------------
  den.aspects.roles.sandbox.dev = {
    includes = with den.aspects; [
      roles.sandbox.minimal

      dev.git.github
      dev.git.lazygit

      dev.lang.node
      dev.lang.python
      dev.lang.nix
      dev.lang.go

      dev.tools.devenv
      dev.tools.direnv
      dev.tools.headless-browser
      dev.tools.herdr
      dev.tools.herdr.autostart
      dev.tools.paseo
      dev.tools.trippy

      shell.atuin
      shell.bat
      shell.delta
      shell.difftastic
      shell.eza
      shell.neovim
      shell.yazi
      shell.zoxide

      shell.bundles.archive
      shell.bundles.data
      shell.bundles.search
      shell.bundles.system
    ];

    homeManager = {
      # /workspace is the only project a sandbox ever has — trust its .envrc
      # without a manual `direnv allow`.
      programs.direnv.config.whitelist.prefix = [ "/workspace" ];

      # ...and start every herdr pane there. herdr's default policy
      # (`terminal.new_cwd = "follow"`) falls back to $HOME whenever a pane has
      # no source workspace to inherit from — which is every pane of the first
      # session after boot — so an interactive `ssh scoite-<name>` landed in
      # /home/iosta however carefully the login shell had cd'd first. A fixed
      # path overrides that for panes, tabs and new workspaces alike.
      xdg.configFile."herdr/config.toml".text = ''
        [terminal]
        new_cwd = "/workspace"
      '';
    };

    # An agent can build/install whatever it likes: the guest store overlay is
    # writable (microvm.writableStoreOverlay) and iosta is a trusted nix user,
    # so `nix profile install` works without a daemon-permission dance; the
    # compilers are here so a `pip install`/`npm rebuild` that drops to C
    # doesn't dead-end.
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.binutils
          pkgs.gcc
          pkgs.gnumake
          pkgs.jq
          pkgs.patchelf
          pkgs.pkg-config
        ];
        nix.settings.trusted-users = [ "iosta" ];
      };
  };
}
