{
  den.aspects.shell = {
    # Fish enabled system-wide so it is a valid login shell on the host.
    # Per-user default shell is set by the `user-shell` battery in users/df.nix.
    os = {
      programs.fish = {
        enable = true;
      };
    };

    nixos =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        environment.enableAllTerminfo = true;
        users.users.root.shell = pkgs.bashInteractive;
        users.defaultUserShell = pkgs.fish;

        # Log diff when system update is applied
        system.activationScripts.diff = {
          supportsDryActivation = true;
          text = ''
            if [[ -e /run/current-system ]]; then
              ${lib.getExe pkgs.nvd} --color=always --nix-bin-dir=${config.nix.package}/bin diff /run/current-system "$systemConfig" || echo "FAILED TO GENERATE DIFF"
            fi
          '';
        };
      };
  };
}
