# Ported from modules/system/ledger.nix. Ledger hardware-wallet udev access.
# The legacy module added the `my.mainUser` to a `ledger` group; in Den the
# group is created here and the user aspect (or a role) adds membership.
{
  den.aspects.hardware.ledger.nixos =
    { lib, ... }:
    {
      hardware.ledger.enable = true;

      users.groups.ledger = { };

      services.udev.extraRules = lib.mkAfter ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="41e5", GROUP="ledger", MODE="0660"
      '';
    };
}

# {
#   config.flake.nixosModules.ledger = {
#     lib,
#     config,
#     ...
#   }: let
#     ledgerGroup = "ledger";
#     mainUser = config.my.mainUser.name;
#   in {
#     config = {
#       hardware.ledger.enable = true;

#       users.groups.${ledgerGroup} = {};
#       users.users.${mainUser}.extraGroups = lib.mkAfter [ledgerGroup];

#       services.udev.extraRules = lib.mkAfter ''
#         SUBSYSTEM=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="41e5", GROUP="${ledgerGroup}", MODE="0660"
#       '';
#     };
#   };
# }
