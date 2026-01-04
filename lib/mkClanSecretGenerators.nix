{ lib }:
let
  sanitize = s: lib.replaceStrings [ " " "/" "." ":" "@" ] [ "_" "_" "_" "_" "_" ] s;

  # helper to build a single generator (one unit) for one secret file
  mkOne =
    {
      folderPath,
      fileName,
      mode,
      share ? true,
      promptPrefix ? "file",
      owner ? "root",
      group ? "root",
    }:
    let
      folderKey = sanitize folderPath;
      fileKey = sanitize fileName;

      genName = "${folderKey}-${fileKey}";
      promptName = "${promptPrefix}-${fileName}";
    in
    {
      ${genName} = {
        inherit share;

        prompts = {
          ${promptName} = {
            description = "The contents for ${folderPath}/${fileName}";
            type = "multiline";
          };
        };

        # still emits the file under the "files" attribute; Clan will place it
        # under the generator output root. Your downstream layout stays consistent.
        files = {
          ${fileName} = {
            secret = true;
            inherit mode owner group;
          };
        };

        script = ''
          set -euo pipefail

          cat "$prompts"/"${promptName}" > "$out"/"${fileName}"

          # Ensure trailing newline if the file is non-empty and doesn't already end with LF.
          if [ -s "$out"/"${fileName}" ]; then
            last="$(tail -c 1 "$out"/"${fileName}" || true)"

            # If last byte was '\n', command substitution strips it => empty string.
            if [ -n "$last" ]; then
              printf '\n' >> "$out"/"${fileName}"
            fi
          fi
        '';
      };
    };

in
{
  # mkClanSecretGenerators :: { folderPath, files, share?, promptPrefix?, owner?, group? } -> attrset
  #
  # files = { "aon.clan" = "0640"; ... }
  mkClanSecretGenerators =
    {
      folderPath,
      files,
      share ? true,
      promptPrefix ? "file",
      owner ? "root",
      group ? "root",
    }:
    lib.foldl' (
      acc: fileName:
      acc
      // mkOne {
        inherit
          folderPath
          fileName
          share
          promptPrefix
          owner
          group
          ;
        mode = files.${fileName};
      }
    ) { } (builtins.attrNames files);
}
