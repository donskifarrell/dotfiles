# Ported from modules/system/keyboard.nix — the X11/Wayland keyboard layout.
# (The console keymap lives in core.locale.)
{
  den.aspects.hardware.keyboard.nixos = _: {
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };
}
