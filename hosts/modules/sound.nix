{
  pkgs, 
...
}: {
  services = {
    pipewire = {
      enable = true;
      
      audio.enable = true;
      alsa.enable = false;
      alsa.support32Bit = false;
      pulse.enable = true;
      wireplumber.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
  };

  sound.enable = true;
}
