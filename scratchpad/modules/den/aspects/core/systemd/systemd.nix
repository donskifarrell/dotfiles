{
  den.aspects.core.systemd = {
    nixos = {
      systemd.tmpfiles.rules = [ ];

      services.journald.extraConfig = ''
        MaxRetentionSec=3month
        SystemMaxUse=2G
      '';
    };
  };
}
