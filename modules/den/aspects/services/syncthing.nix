# Syncthing on abhaile — syncs df's Obsidian vault (~/vaults/main) with the
# Android phone (Syncthing-Fork). Architecture + one-time manual steps
# (pairing, obsidian-git install): docs/obsidian.md.
#
# Runs as a SYSTEM service but AS df (vault files must be owned by uid 1000
# for Obsidian, obsidian-git, and the sandvm virtiofs passthrough). Keys/certs
# are syncthing-generated on first start under /home/df/.config/syncthing; to
# adopt the pre-staged sops secrets later (secrets/abhaile.nix has commented
# abhaile-syncthing-{key,cert,api} entries — owner must become df, not
# "syncthing"), point services.syncthing.{key,cert} at the sops paths.
#
# Device IDs are public keys — safe to commit. overrideDevices /
# overrideFolders stay at their default (true): this file is the source of
# truth; devices/folders added via the GUI are reverted on restart.
#
# Future MacBook: a parallel home-manager `services.syncthing` user service
# with the SAME folder id ("vault-main") — do not reuse this aspect there.
{
  den.aspects.services.syncthing.nixos = {
    # Vault skeleton; syncthing, Obsidian and sandvm all want it df-owned.
    systemd.tmpfiles.rules = [
      "d /home/df/vaults 0755 df users -"
      "d /home/df/vaults/main 0755 df users -"
      "d /home/df/vaults/main/drop 0755 df users -"
    ];

    services.syncthing = {
      enable = true;
      user = "df";
      group = "users";
      dataDir = "/home/df"; # configDir defaults to /home/df/.config/syncthing
      openDefaultPorts = true; # TCP+UDP 22000 transfers, UDP 21027 discovery
      # guiAddress: default 127.0.0.1:8384 (localhost-only; df is the only user)

      settings = {
        options.urAccepted = -1; # no usage reporting

        devices = {
          # Android phone (Syncthing-Fork). Fill in after reading the ID off
          # the phone (Settings -> Show device ID), then also flip the
          # folder's devices list below. TODO.md: "Obsidian vault follow-ups".
          phone.id = "22FKIP2-SLDTG5G-MCOUSM3-JP3SYSH-7X5WPE2-K7RWTRT-M7RDW3C-MIYJAQF";
        };

        folders."/home/df/vaults/main" = {
          id = "vault-main"; # must match on every device, incl. future macbook
          label = "vault-main";
          type = "sendreceive";
          devices = [ "phone" ]; # -> [ "phone" ] once the device block above is real
          # Backstop against phone-side deletions/overwrites; .stversions/ is
          # never synced and sits in the vault's .gitignore.
          versioning = {
            type = "trashcan";
            params.cleanoutDays = "14";
          };
          # Declarative .stignore (pushed over the REST API by the module's
          # syncthing-init unit). git history stays host-only (GitHub is the
          # backup channel); the workspace files are per-device UI state.
          ignorePatterns = [
            ".git"
            ".trash"
            ".obsidian/workspace.json"
            ".obsidian/workspace-mobile.json"
            ".obsidian/cache"
            "(?d).DS_Store"
            "(?d)Thumbs.db"
          ];
        };
      };
    };
  };
}
