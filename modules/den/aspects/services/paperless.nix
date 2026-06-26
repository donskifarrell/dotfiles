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

# {
#   config.flake.nixosModules.paperless =
#     {
#       config,
#       pkgs,
#       ...
#     }:
#     let
#       localDataDir = "/var/lib/paperless";
#     in
#     {
#       config = {
#         # users.users.${config.my.mainUser.name}.extraGroups = [ "paperless" ];

#         # systemd.mounts = [
#         #   {
#         #     what = "/home/${config.my.mainUser.name}/consume";
#         #     where = "${localDataDir}/consume";
#         #     type = "none";
#         #     options = "bind";

#         #     # Ensure /home is mounted before we try the bind mount
#         #     after = [ "home.mount" ];
#         #     requires = [ "home.mount" ];

#         #     wantedBy = [ "multi-user.target" ];
#         #   }
#         # ];

#         # systemd.tmpfiles.rules = [
#         #   # Ensure both sides exist
#         #   "d /home/${config.my.mainUser.name}/consume 0770 ${config.my.mainUser.name} paperless -"
#         #   "d ${localDataDir} 0750 paperless paperless -"
#         #   "d ${localDataDir}/consume 0750 paperless paperless -"
#         # ];

#         services.paperless = {
#           enable = true;

#           # Use postgresql
#           database.createLocally = true;

#           # Where Paperless stores its data
#           dataDir = localDataDir;

#           # Web UI
#           address = "127.0.0.1";
#           port = 28981;

#           configureTika = true;

#           settings = {
#             PAPERLESS_URL = "http://localhost:28981";
#             PAPERLESS_TIME_ZONE = "Europe/London";
#             PAPERLESS_OCR_LANGUAGE = "eng";

#             # PAPERLESS_OCR_MODE = "skip";
#             # PAPERLESS_OCR_CLEAN = "true";
#             PAPERLESS_TASK_WORKERS = "2";
#           };
#         };
#       };
#     };
# }
