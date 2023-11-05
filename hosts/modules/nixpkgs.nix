{
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      allowInsecure = false;
      allowUnsupportedSystem = true;

      # Workaround fix: https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = pkg: true;

      permittedInsecurePackages = [
        "openssl-1.1.1w" # For Sublime4 install: https://github.com/NixOS/nixpkgs/issues/239615
      ];
    };

    overlays =
      # Apply each overlay found in the /overlays directory
      let
        path = ../../overlays;
      in
        with builtins;
          map (n: import (path + ("/" + n)))
          (filter (n:
            match ".*\\.nix" n
            != null
            || pathExists (path + ("/" + n + "/default.nix")))
          (attrNames (readDir path)));
  };
}
