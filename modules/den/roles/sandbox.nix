# role-sandbox.* — the two sandbox tiers a `scoite` guest can be built from.
# `dev` includes `minimal`, so the closures nest and a launch only pays for
# what its type actually needs:
#
#   minimal  shell + git + the agent harness, with internet access and nothing
#            else — for "run this thing somewhere it can't touch my machine".
#   dev      (default) the working sandbox: python, node, headless chromium,
#            compilers/nix-ld, the full TUI shell + git stack, devenv/direnv,
#            and the paseo daemon on :6767. The guest's nix store
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
{ den, inputs, ... }:
{
  # --- minimal ---------------------------------------------------------
  # roles.default already carries `shell` + shell.bundles.base, so this is
  # only the delta: an interactive fish, git, and the agent tools.
  den.aspects.roles.sandbox.minimal = {
    includes = with den.aspects; [
      shell.fish
      shell.starship
      dev.git
      apps.ai-tools
    ];

    # `omp` in a sandbox means `omp --config ~/.omp/agent/config.sandbox.yml`
    # (df, 2026-08-26): that overlay is the near-zero-approval command policy
    # that only makes sense when the VM itself is the containment boundary.
    # The file is df's, copied in from the host with the rest of the omp
    # config (the `OMP_CONF` credential — see pkgs/by-name/scoite).
    #
    # A wrapper rather than a shell alias, because the callers that matter are
    # not interactive shells: the paseo daemon spawning an agent, a systemd
    # unit, `scoite ssh <name> -- omp -p '…'`. `hiPrio` is what lets it win
    # the `bin/omp` collision against apps.ai-tools' real omp in the same
    # home-manager profile; the guard keeps a guest whose host has no such
    # overlay working exactly as before.
    homeManager =
      { pkgs, lib, ... }:
      let
        realOmp = inputs.nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system}.omp;
      in
      {
        home.packages = [
          (lib.hiPrio (
            pkgs.writeShellScriptBin "omp" ''
              cfg="$HOME/.omp/agent/config.sandbox.yml"
              if [ -f "$cfg" ]; then
                exec ${realOmp}/bin/omp --config "$cfg" "$@"
              fi
              exec ${realOmp}/bin/omp "$@"
            ''
          ))
        ];
      };
  };

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
