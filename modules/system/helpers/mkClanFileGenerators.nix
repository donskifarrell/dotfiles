{ lib }:
let
  # Normalize keys for generator names - avoid weird chars
  sanitize = s: lib.replaceStrings [ "/" " " ] [ "_" "_" ] s;

  mkOne =
    {
      folderPath,
      fileName,
      mode,
      share ? true,
      promptKey ? "file-contents",
    }:
    {
      name = "${sanitize folderPath}/${sanitize fileName}";
      value = {
        inherit share;

        prompts.${promptKey} = {
          description = "The contents for ${fileName}";
          type = "multiline";
          # to store prompts in fs:
          # persist = true;
        };

        files.${fileName} = {
          secret = true;
          mode = mode; # e.g. "0600"
        };

        script = ''
          cat "$prompts"/${promptKey} > "$out"/${fileName}
        '';
      };
    };

in
{
  mkClanFileGenerators =
    {
      folderPath,
      files,
      share ? true,
      promptKey ? "file-contents",
    }:
    lib.listToAttrs (
      lib.mapAttrsToList (
        fileName: mode:
        mkOne {
          inherit
            folderPath
            fileName
            mode
            share
            promptKey
            ;
        }
      ) files
    );
}
