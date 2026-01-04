{ lib }:
let
  # Normalize keys for generator names - avoid weird chars
  sanitize = s: lib.replaceStrings [ " " ] [ "_" ] s;
in
{
  # mkClanSecretGenerators :: { folderPath, files, share?, promptPrefix? } -> attrset
  #
  # files = {
  #   "sshconfig.local" = "0600";
  # };
  mkClanSecretGenerators =
    {
      folderPath,
      files,
      share ? true,
      promptPrefix ? "file",
      owner ? "root",
      group ? "root",
    }:
    let
      folderKey = sanitize folderPath;

      # One prompt per file (unique key), but still stored under the same generator folder.
      prompts = lib.mapAttrs' (
        fileName: _mode:
        lib.nameValuePair "${promptPrefix}-${fileName}" {
          description = "The contents for ${folderPath}/${fileName}";
          type = "multiline";
          # persist = true; # enable to store prompt inputs to fs
        }
      ) files;

      # files attrset: files."<fileName>" = { secret=true; mode=...; }
      fileDefs = lib.mapAttrs (_fileName: mode: {
        secret = true;
        inherit mode owner group;
      }) files;

      # Script writes each prompt to its matching output filename
      scriptLines = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (fileName: _mode: ''
          cat "$prompts"/"${promptPrefix}-${fileName}" > "$out"/"${fileName}"
          if [ "$(tail -c 1 "$out"/"${fileName}" | wc -c)" -ne 0 ]; then
            # file is non-empty; ensure it ends with LF
            if ! tail -c 1 "$out"/"${fileName}" | grep -q $'\n'; then
              printf '\n' >> "$out"/"${fileName}"
            fi
          fi
        '') files
      );
    in
    {
      ${folderKey} = {
        inherit share;
        prompts = prompts;
        files = fileDefs;

        script = ''
          set -euo pipefail
          ${scriptLines}
        '';
      };
    };
}
