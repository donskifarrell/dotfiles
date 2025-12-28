{
  config.flake.nixosModules.bootlabel =
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
      config = {
        system.nixos.label = "${timestamp}--v${config.system.nixos.version}";
      };
    };
}
