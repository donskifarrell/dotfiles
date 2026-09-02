# Ported from modules/system/keyboard.nix — the X11/Wayland keyboard layout.
# (The console keymap lives in core.locale.)
{
  den.aspects.hardware.keyboard.nixos = { pkgs, ... }: {
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    environment.systemPackages = [
      pkgs.keychron-udev-rules
    ];
  };
}
