# Host `try` — a throwaway clan VM to prove the graduated den composition.
#
# Unlike `scratchpad/hosts/short.nix`, this host carries NO bare-metal hardware
# aspects (AMD cpu/gpu, facter, disko). The VM's hardware report + disk layout
# are owned by clan's machine dir (machines/try/{facter.json,disko.nix}), which
# clan auto-imports. den only composes the feature set here.
#
# `intoAttr = [ ]` stops den from emitting its own `nixosConfigurations.try`
# (which would collide with clan's). Instead `bridge.nix` exposes this host's
# composed `mainModule` as `flake.nixosModules.try-den`, and
# `machines/try/configuration.nix` imports it — clan stays the builder/deployer.
{ den, ... }:
let
  # Lifted from machines/abhaile — swap for the clan-managed key later.
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.hosts.x86_64-linux.try = {
    intoAttr = [ ]; # clan owns nixosConfigurations.try
    users.df = { };
  };

  # Host aspect (auto-applied to `try`): the full abhaile-like desktop stack.
  den.aspects.try = {
    includes = with den.aspects; [
      roles.default # nix, locale, ssh, shell base, systemd/boot
      roles.workstation # shell + dev + cli home apps
      roles.dev # git, langs, dev tools
      roles.desktop # GNOME, sound, flatpak, appimage, productivity apps
    ];

    nixos = _: {
      users.users.root.openssh.authorizedKeys.keys = [ authorizedKey ];
    };
  };
}
