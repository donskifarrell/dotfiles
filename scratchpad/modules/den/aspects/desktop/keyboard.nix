# Ported from modules/system/keyboard.nix — the X11/Wayland keyboard layout.
# (The console keymap lives in core.i18n.)
{
  den.aspects.desktop.keyboard.nixos = _: {
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };
}
