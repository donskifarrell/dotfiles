{
  config.flake.nixosModules.secrets-user =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.secretsUser;

      user = cfg.user;
      home = cfg.home;

      # Must match sanitize() in mkClanSecretGenerators.nix
      sanitize = s: lib.replaceStrings [ " " "/" "." ":" "@" ] [ "_" "_" "_" "_" "_" ] s;

      # Given folder + file, compute the generator name
      generatorFor = folder: file: "${sanitize folder}-${sanitize file}";

      # Compute the actual source path of a secret
      srcFor =
        folder: file:
        let
          gen = generatorFor folder file;
        in
        "${cfg.secretsRoot}/${gen}/${file}";

      linkRule =
        folder: file: destPath:
        "L+ ${home}/${destPath} - - - - ${srcFor folder file}";

      # tmpfiles ACL rule: give user read access to the secret target
      # (symlink ownership doesn't matter; target readability does)
      # aclRule = folder: file: "a+ ${srcFor folder file} - - - - u:${user}:r";

      # Ensure the folder under secretsRoot is traversable by the user.
      # Dirs are typically 0750 root:root; give user `x` via ACL.
      # Avoids “permission denied” on traversal.
      # aclDirRule = folder: "a+ ${cfg.secretsRoot}/${folder} - - - - u:${user}:x";

      # spec = { folder, destDir, files, dirs }
      linkSpec =
        spec:
        let
          folder = spec.folder;
          destDir = spec.destDir;
          files = spec.files;
          dirs = spec.dirs;
        in
        # Create required directories first
        (map (d: "d ${home}/${d} 0700 ${user} ${cfg.group} - -") dirs)
        ++ (map (f: linkRule folder f "${destDir}/${f}") files);

      # aclSpec =
      #   spec:
      #   let
      #     folder = spec.folder;
      #     files = spec.files;
      #   in
      #   # Ensure traversal on /run/secrets/vars/<folder>
      #   [ (aclDirRule folder) ]
      #   # Ensure user can read each file
      #   ++ (map (f: aclRule folder f) files);
    in
    {
      options.secretsUser = {
        enable = lib.mkEnableOption "Symlink clan runtime secrets into the user's home directory";

        # Defaults to your existing pattern
        user = lib.mkOption {
          type = lib.types.str;
          default = config.my.mainUser.name;
          description = "User to install the symlinks for.";
        };

        home = lib.mkOption {
          type = lib.types.str;
          default = "/home/${config.my.mainUser.name}";
          description = "Home directory for the target user.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "users";
          description = "Group ownership to set on created directories.";
        };

        secretsRoot = lib.mkOption {
          type = lib.types.str;
          default = "/run/secrets/vars";
          description = "Root directory where runtime secrets are available.";
        };

        ssh = lib.mkOption {
          type = lib.types.submodule (
            { ... }:
            {
              options = {
                enable = lib.mkEnableOption "SSH secrets symlinks" // {
                  default = true;
                };

                folder = lib.mkOption {
                  type = lib.types.str;
                  default = "ssh";
                  description = "Folder under secretsRoot containing SSH files.";
                };

                destDir = lib.mkOption {
                  type = lib.types.str;
                  default = ".ssh";
                  description = "Destination directory relative to home.";
                };

                dirs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ".ssh" ];
                  description = "Directories (relative to home) to create for SSH symlinks.";
                };

                files = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "SSH files to symlink (filenames only).";
                };
              };
            }
          );
          default = { };
        };

        git = lib.mkOption {
          type = lib.types.submodule (
            { ... }:
            {
              options = {
                enable = lib.mkEnableOption "Git secrets symlinks" // {
                  default = true;
                };

                folder = lib.mkOption {
                  type = lib.types.str;
                  default = "git";
                  description = "Folder under secretsRoot containing Git files.";
                };

                destDir = lib.mkOption {
                  type = lib.types.str;
                  default = ".config/git";
                  description = "Destination directory relative to home.";
                };

                dirs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [
                    ".config"
                    ".config/git"
                  ];
                  description = "Directories (relative to home) to create for Git symlinks.";
                };

                files = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Git files to symlink (filenames only).";
                };
              };
            }
          );
          default = { };
        };
      };

      config = lib.mkIf cfg.enable {
        users.groups.secrets = { };
        users.users.${cfg.user}.extraGroups = lib.mkAfter [ "secrets" ];

        systemd.tmpfiles.rules =
          # Home dirs + symlinks
          (lib.optionals cfg.ssh.enable (linkSpec cfg.ssh))
          ++ (lib.optionals cfg.git.enable (linkSpec cfg.git));
        # ACLs on secret targets (and their folders)
        # ++ (lib.optionals cfg.ssh.enable (aclSpec cfg.ssh))
        # ++ (lib.optionals cfg.git.enable (aclSpec cfg.git));

        systemd.services.apply-clan-secret-acls = {
          description = "Apply ACLs to clan secrets after they exist";
          wantedBy = [ "multi-user.target" ];
          after = [ "multi-user.target" ];

          # systemd-tmpfiles typically runs at boot; Clan may materialize /run/secrets/... later.
          # If tmpfiles applies ACLs before the file exists, nothing happens.
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.systemd}/bin/systemd-tmpfiles --create";
          };
        };
      };
    };
}
