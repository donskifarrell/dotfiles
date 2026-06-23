{
  description = "Den MVP scratchpad — host `short` + user `df` (see ../PLAN.md step 1.3)";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Consumes machines/short/facter.json (hardware report) — same one clan uses.
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";

    den.url = "github:denful/den";

    # Used by the desktop/dev aspects ported from the main repo. Only forced
    # when a host includes the vscode / claude aspects (server `short` does not),
    # so they stay lazy for the MVP build.
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code.url = "github:sadjow/claude-code-nix";
  };

  # Same shape as the real dotfiles: flake-parts + import-tree auto-imports
  # every file under ./modules. Den's flakeModule is wired in modules/den/den.nix.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
