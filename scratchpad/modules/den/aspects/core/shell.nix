# Fish enabled system-wide so it is a valid login shell on the host.
# Per-user default shell is set by the `user-shell` battery in users/df.nix.
{
  den.aspects.core.shell.nixos = _: {
    programs.fish.enable = true;
  };
}
