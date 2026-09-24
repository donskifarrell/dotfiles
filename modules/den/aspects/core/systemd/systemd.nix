{
  den.aspects.core.systemd = {
    nixos = {
      systemd.tmpfiles.rules = [ ];

      # Was `services.journald.extraConfig` (a raw journald.conf fragment) until
      # 2026-09-24, when nixpkgs turned that option into a hard assertion. The
      # structured form is a straight translation -- same keys, same journald.conf.
      services.journald.settings.Journal = {
        MaxRetentionSec = "3month";
        SystemMaxUse = "2G";
      };
    };
  };
}
