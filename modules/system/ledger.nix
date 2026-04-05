{
  config.flake.nixosModules.ledger = {
    lib,
    config,
    ...
  }: let
    ledgerGroup = "ledger";
    mainUser = config.my.mainUser.name;
  in {
    config = {
      hardware.ledger.enable = true;

      users.groups.${ledgerGroup} = {};
      users.users.${mainUser}.extraGroups = lib.mkAfter [ledgerGroup];

      services.udev.extraRules = lib.mkAfter ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="41e5", GROUP="${ledgerGroup}", MODE="0660"
      '';
    };
  };
}
