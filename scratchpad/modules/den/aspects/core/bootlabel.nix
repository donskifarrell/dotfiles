# Ported from modules/system/bootlabel.nix. Stamps each generation's boot menu
# entry with a build timestamp + nixos version for easier rollbacks.
{
  den.aspects.core.bootlabel.nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      timestamp = lib.readFile "${pkgs.runCommand "timestamp" {
        env.when = builtins.currentTime;
      } "echo -n `date -d @$when +%Y%m%d_%X` > $out"}";
    in
    {
      system.nixos.label = "${timestamp}--v${config.system.nixos.version}";
    };
}
