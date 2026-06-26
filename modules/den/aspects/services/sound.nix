# Ported from modules/system/sound.nix. PipeWire (ALSA + Pulse) with rtkit.
{
  den.aspects.services.sound.nixos =
    { pkgs, ... }:
    {
      security.rtkit.enable = true;

      services = {
        pipewire = {
          enable = true;

          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
        };

        pulseaudio.enable = false;
      };

      environment.systemPackages = [ pkgs.pavucontrol ];
    };
}
