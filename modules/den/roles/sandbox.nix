# role-sandbox.* — the four sandbox tiers a `sandvm` guest can be built from.
# Each tier includes the one below it, so the closures nest and a launch only
# pays for what its type actually needs:
#
#   minimal      shell + git + the agent harness. No dev toolchain at all —
#                for "run this thing somewhere it can't touch my machine".
#   generic      + a compiler/build toolchain, nix-ld and the full TUI shell
#                environment. This is the "plain Linux box the agent installs
#                its own tools into" tier: the guest's nix store overlay and
#                home are both persistent, so `nix profile install` /
#                `npm i -g` / `pip install --user` survive stop→start.
#   devenv       + devenv.sh/direnv + herdr + headless chromium. The project
#                declares its own toolchain in devenv.nix/flake.nix and the
#                guest pre-builds it at boot (sandvm-workspace-init in
#                virtualisation/microvm-guest.nix).
#   workstation  + df's language toolchains, for parity with abhaile when a
#                project has no declared environment of its own.
#
# One tier per Den host in modules/den/hosts/sandvm.nix; the CLI's `--type`
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

  # --- generic ---------------------------------------------------------
  den.aspects.roles.sandbox.generic = {
    includes = with den.aspects; [
      roles.sandbox.minimal

      dev.git.github
      dev.git.lazygit
      dev.tools.direnv

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

    # The point of this tier: an agent can build/install whatever it likes.
    # The guest store overlay is writable (microvm.writableStoreOverlay) and
    # iosta is a trusted nix user, so `nix profile install` works without a
    # daemon-permission dance; the compilers are here so a `pip install`/
    # `npm rebuild` that drops to C doesn't dead-end.
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

  # --- devenv ----------------------------------------------------------
  den.aspects.roles.sandbox.devenv = {
    includes = with den.aspects; [
      roles.sandbox.generic

      dev.tools.devenv
      dev.tools.headless-browser
      dev.tools.herdr
      dev.tools.herdr.autostart
    ];

    # /workspace is the only project a sandbox ever has — trust its .envrc
    # without a manual `direnv allow`.
    homeManager.programs.direnv.config.whitelist.prefix = [ "/workspace" ];
  };

  # --- workstation -----------------------------------------------------
  den.aspects.roles.sandbox.workstation.includes = with den.aspects; [
    roles.sandbox.devenv

    dev.lang.go
    dev.lang.nix
    dev.lang.python
    dev.tools.trippy
  ];
}
