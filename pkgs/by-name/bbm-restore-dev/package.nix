# `bbm-restore-dev [dir]` — copy abhaile's latest bbm backup pull
# (/var/lib/bbm-backup/latest, services/bbm-backup.nix) over a dev data dir,
# default ~/dev/bbm/data. Integrity-checks and replaces sqlite.db (+ drops
# -wal/-shm), mirrors the backup's data/ subdirs with --delete; other local
# top-level entries (agent/, analysis/, …) are protected. Stop the dev server first.
{
  writeShellApplication,
  coreutils,
  sqlite,
  rsync,
}:
let
  dest = "/var/lib/bbm-backup";
in
writeShellApplication {
  name = "bbm-restore-dev";
  runtimeInputs = [
    coreutils
    sqlite
  ];
  text = ''
    target="''${1:-$HOME/dev/bbm/data}"
    [ -d "$target" ] || { echo "bbm-restore-dev: no such dir: $target" >&2; exit 1; }
    src="${dest}/$(sudo readlink ${dest}/latest)"
    echo "restoring $src -> $target"
    owner="$(id -un):$(id -gn)"

    tmp="$target/.sqlite.db.restore"
    sudo install -m 0640 -o "''${owner%:*}" -g "''${owner#*:}" "$src/backup/sqlite.db" "$tmp"
    [ "$(sqlite3 "$tmp" 'pragma integrity_check;')" = ok ] \
      || { rm -f "$tmp"; echo "bbm-restore-dev: backup db failed integrity_check" >&2; exit 1; }
    rm -f "$target/sqlite.db-wal" "$target/sqlite.db-shm"
    mv "$tmp" "$target/sqlite.db"

    # sudo's secure_path drops runtimeInputs, hence the store path.
    sudo ${rsync}/bin/rsync -rlpt --delete --filter='protect /*' \
      --chown="$owner" --chmod=go= "$src/data/" "$target/"
    echo "restored into $target"
  '';
}
