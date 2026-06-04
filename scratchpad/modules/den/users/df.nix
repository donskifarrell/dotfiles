# User `df` — one file: the user aspect (auto-applied to user `df`).
{ den, ... }:
let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6h5RafG9hYqgT3nviJO9P9eEUEAHJlIEqFWfoxFOP6";
in
{
  den.aspects.df = {
    includes = [
      den.batteries.primary-user # isNormalUser + wheel + networkmanager
      (den.batteries.user-shell "fish") # default shell + enable fish at OS/HM
    ];

    # df's NixOS-side config on every host it lives on.
    nixos = {
      users.users.df.openssh.authorizedKeys.keys = [ authorizedKey ];
    };

    # df's home-manager config (minimal for the MVP — grow with dev-tools etc.).
    homeManager = {
      programs.git = {
        enable = true;
        userName = "df";
        userEmail = "donal@donalfarrell.com";
      };
    };
  };
}
