# bbm backups: eachtrach snapshots, abhaile pulls. Two aspects, one per side,
# neither implied by services.bbm — a host takes only its half.
#
# What is actually irreplaceable is `data/` (raw GoCardless feed pulls, the
# uploaded CSV/PDF statements, Telegram transcripts): the ledger can be rebuilt
# from those files, but they cannot be rebuilt from the ledger. So the pull
# takes the whole state directory, not just the database.
#
# The live sqlite.db is EXCLUDED and a `.backup` snapshot copied instead.
# rsync-ing a WAL database while the server is writing yields a torn file that
# still looks like a valid backup — the worst possible failure mode for the one
# thing you only find out about during a restore.
{ inputs, ... }:
{
  # --- eachtrach side: snapshot + a read-only account to pull it -----------
  den.aspects.services.bbm.backup.nixos =
    { pkgs, ... }:
    let
      stateDir = "/var/lib/bbm";

      # abhaile root's key for this job and nothing else. Public half, so it
      # belongs in git; the private half is sops (see the .pull aspect).
      pullKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMTzso1lhCLhRYG0SqpyKw1izpxVGACQKM65Fyawsai bbm-backup: abhaile root -> eachtrach (read-only rsync of /var/lib/bbm)";

      # Forced command. nixpkgs' rsync ships no `rrsync` (checked: the output
      # has only rsync and rsync-ssl), so this does rrsync's job directly:
      # accept only the read-only server mode rsync uses to SEND files, and
      # only for paths under the bbm state directory. `--sender` is the part
      # that makes writes impossible; the path check stops the account being
      # used to read the rest of the filesystem.
      forcedCommand = pkgs.writeShellScript "bbm-backup-rsync-only" ''
        refuse() {
          echo "bbm-backup: only read-only rsync of ${stateDir} is permitted" >&2
          exit 1
        }
        [ -n "''${SSH_ORIGINAL_COMMAND:-}" ] || refuse

        # Word-split the requested command with globbing disabled. No path
        # under ${stateDir} contains whitespace, and rsync generates these
        # arguments itself.
        set -f
        # shellcheck disable=SC2086
        set -- $SSH_ORIGINAL_COMMAND
        [ "$1" = "rsync" ] || refuse
        [ "$2" = "--server" ] || refuse
        [ "$3" = "--sender" ] || refuse

        for last; do :; done
        case "$last" in
          ${stateDir} | ${stateDir}/*) ;;
          *) refuse ;;
        esac

        shift
        exec ${pkgs.rsync}/bin/rsync "$@"
      '';
    in
    {
      # Reads only. Its primary group is bbm, which grants exactly the group
      # bit on 0750 dirs / 0640 files — no write anywhere, by permission and
      # not merely by policy. A shell is required because sshd runs a forced
      # command through it.
      users.users.bbm-backup = {
        isSystemUser = true;
        group = "bbm";
        home = "/var/empty";
        shell = pkgs.bash;
        description = "bbm backup pull account (read-only)";
        openssh.authorizedKeys.keys = [
          "restrict,command=\"${forcedCommand}\" ${pullKey}"
        ];
      };

      # A consistent copy of the database, taken by sqlite itself so it is
      # never a half-written page. Runs as bbm because only bbm may write here.
      systemd.services.bbm-snapshot = {
        description = "Snapshot the bbm database for backup";
        serviceConfig = {
          Type = "oneshot";
          User = "bbm";
          Group = "bbm";
          UMask = "0027";
          ExecStart = pkgs.writeShellScript "bbm-snapshot" ''
            set -euo pipefail
            mkdir -p ${stateDir}/backup
            ${pkgs.sqlite}/bin/sqlite3 "file:${stateDir}/sqlite.db?mode=ro" \
              ".backup '${stateDir}/backup/sqlite.db'"
          '';
        };
      };

      systemd.timers.bbm-snapshot = {
        description = "Daily bbm database snapshot";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          # Before the pull (03:30), with room for a slow snapshot.
          OnCalendar = "03:00";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
      };
    };

  # --- abhaile side: pull and rotate --------------------------------------
  den.aspects.services.bbm.backup.pull.nixos =
    { config, pkgs, ... }:
    let
      remote = "bbm-backup@eachtrach";
      source = "/var/lib/bbm/";
      dest = "/var/lib/bbm-backup";
      keep = 14;
      keyFile = config.sops.secrets."ssh/bbm_backup".path;
    in
    {
      sops.secrets."ssh/bbm_backup" = {
        sopsFile = inputs.self + "/secrets/shared.yaml";
        key = "ssh/bbm_backup";
        mode = "0400"; # owner root: the unit below runs as root
      };

      systemd.services.bbm-backup-pull = {
        description = "Pull the bbm state directory from eachtrach";
        # Reaches eachtrach by its tailnet name (services.tailscale syncs the
        # alias into /etc/hosts), so this waits for tailscale, not just a route.
        after = [
          "network-online.target"
          "tailscaled.service"
        ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "bbm-backup-pull" ''
            set -euo pipefail
            stamp="$(${pkgs.coreutils}/bin/date +%Y-%m-%d)"
            ${pkgs.coreutils}/bin/mkdir -p ${dest}
            # Root-only. This tree is a bank ledger and every statement file
            # behind it; the default 0755 would let any local account list it.
            ${pkgs.coreutils}/bin/chmod 0700 ${dest}

            # Hardlink unchanged files against the previous run, so 14 dailies
            # cost roughly one copy plus the churn. Absent on the first run.
            link=()
            if [ -e ${dest}/latest ]; then
              link=(--link-dest=${dest}/latest)
            fi

            # -rlptD is -a without -o/-g: modes and times are preserved, but
            # ownership is NOT. Carrying the remote's uid/gid over (-a, or
            # worse --numeric-ids) lands the files owned by whatever local
            # accounts happen to hold eachtrach's bbm uid — on abhaile that
            # resolved to unrelated system users, who could then read the
            # ledger. Root-owned with the same 0640/0750 modes is what we want.
            ${pkgs.rsync}/bin/rsync -rlptD --delete \
              -e '${pkgs.openssh}/bin/ssh -i ${keyFile} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o BatchMode=yes' \
              "''${link[@]}" \
              --exclude=/sqlite.db --exclude=/sqlite.db-wal --exclude=/sqlite.db-shm \
              ${remote}:${source} "${dest}/daily.$stamp/"

            ${pkgs.coreutils}/bin/ln -sfn "daily.$stamp" ${dest}/latest

            # Prune oldest first. `latest` is a symlink, never matched by the
            # daily.* glob's sort.
            ${pkgs.coreutils}/bin/ls -1d ${dest}/daily.* \
              | ${pkgs.coreutils}/bin/sort -r \
              | ${pkgs.coreutils}/bin/tail -n +${toString (keep + 1)} \
              | ${pkgs.findutils}/bin/xargs -r ${pkgs.coreutils}/bin/rm -rf
          '';
        };
      };

      systemd.timers.bbm-backup-pull = {
        description = "Daily bbm backup pull from eachtrach";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "03:30";
          Persistent = true;
          RandomizedDelaySec = "10m";
        };
      };
    };
}
