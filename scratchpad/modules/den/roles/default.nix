{ den, ... }:
{
  den.aspects.roles.default = {
    includes = with den.aspects; [
      core.disable-docs
      core.home-manager
      core.locale
      core.network.avahi
      core.network.manager
      core.network.openssh
      core.nix
      core.nix.nh
      core.nix.nixpkgs
      core.security
      core.stateVersion
      core.systemd
      core.systemd.boot

      shell
      shell.bundles.base
    ];
  };
}
