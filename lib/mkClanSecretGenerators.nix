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
        group = "secrets";
        inherit mode;
      }) files;

      # Script writes each prompt to its matching output filename
      scriptLines = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (fileName: _mode: ''
          cat "$prompts"/"${promptPrefix}-${fileName}" > "$out"/"${fileName}"
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
