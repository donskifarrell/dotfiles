# core/locale — system locale, timezone, and console keymap. en_GB is the
# default (with en_US also generated); timezone Europe/Dublin. Ported from
# modules/system/i18n.nix (+ console keymap from modules/system/keyboard.nix
# and timeZone from machines/short). Renamed from the old `core.i18n` to the
# broader `core.locale` per the taxonomy (core → locale).
{
  den.aspects.core.locale.nixos = _: {
    time.timeZone = "Europe/Dublin";

    i18n = {
      defaultLocale = "en_GB.UTF-8";

      extraLocaleSettings = {
        LC_ADDRESS = "en_GB.UTF-8";
        LC_IDENTIFICATION = "en_GB.UTF-8";
        LC_MEASUREMENT = "en_GB.UTF-8";
        LC_MONETARY = "en_GB.UTF-8";
        LC_NAME = "en_GB.UTF-8";
        LC_NUMERIC = "en_GB.UTF-8";
        LC_PAPER = "en_GB.UTF-8";
        LC_TELEPHONE = "en_GB.UTF-8";
        LC_TIME = "en_GB.UTF-8";
      };

      supportedLocales = [
        "en_GB.UTF-8/UTF-8"
        "en_US.UTF-8/UTF-8"
      ];
    };

    console = {
      keyMap = "us";
      # font = lib.mkDefault "Lat2-Terminus16"; # TODO(check): console font
    };
  };
}
