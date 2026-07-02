{
  writeShellApplication,
  nix,
}:
writeShellApplication {
  name = "nix-flake-write";
  meta.description = "Regenerate flake.nix from the flake-file modules";
  runtimeInputs = [ nix ];
  text = ''
    # Re-evaluate the current tree on every run so edits to flake-file.inputs
    # land, instead of baking a stale generator into the dev shell.
    exec nix run .#write-flake -- "$@"
  '';
}
