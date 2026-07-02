{
  writeShellApplication,
  nix,
}:
writeShellApplication {
  name = "den-tree";
  meta.description = "Print the Den aspect tree applied to each host and user";
  runtimeInputs = [ nix ];
  text = ''
    # Rendered by modules/flake-parts/den-tree.nix from the live den config.
    exec nix eval --raw .#lib.den-tree "$@"
  '';
}
