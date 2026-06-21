# Ported from modules/system/paperless.nix. Document management with a local
# postgres + Tika. The legacy module's commented-out consume-folder bind mounts
# were left out — re-add them as a separate aspect when wiring real ingest.
{
  den.aspects.services.storage.paperless.nixos = _: {
    services.paperless = {
      enable = true;

      database.createLocally = true;
      dataDir = "/var/lib/paperless";

      address = "127.0.0.1";
      port = 28981;

      configureTika = true;

      settings = {
        PAPERLESS_URL = "http://localhost:28981";
        PAPERLESS_TIME_ZONE = "Europe/London";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_TASK_WORKERS = "2";
      };
    };
  };
}
