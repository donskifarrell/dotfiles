{ inputs, ... }:
{
  flake-file.inputs.devshell = {
    url = "github:numtide/devshell";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  imports = [
    inputs.devshell.flakeModule
  ];

  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      devshells.default = {
        packages = [
          pkgs.git
          pkgs.nix # Always use the nix version from this flake's nixpkgs version, so that nix-plugins (below) doesn't fail because of different nix versions.
          pkgs.nixos-rebuild # Ensure nixos-rebuild is available for darwin systems
          pkgs.nix-output-monitor
          pkgs.nix-fast-build
          pkgs.nil
          pkgs.nixd
          pkgs.sops
          pkgs.ssh-to-age
          pkgs.age
        ]
        ++ lib.optionals pkgs.stdenv.buildPlatform.isDarwin [
          pkgs.coreutils-full # Include GNU coreutils for darwin systems
        ];

        commands = [
          {
            package = pkgs.nh;
            help = "Nix helper for nixpkgs development";
          }
          {
            # nixpkgs' binary (cached); the activation lib in flake.deploy
            # comes from the deploy-rs input (modules/flake-parts/deploy.nix).
            package = pkgs.deploy-rs;
            name = "deploy";
            help = "deploy-rs remote deploy (deploy .#<host>; magic rollback on lost ssh)";
          }
          {
            package = pkgs.nixos-anywhere;
            help = "Provision a fresh host over ssh (kexec's stock Ubuntu images into NixOS)";
          }
          {
            package = config.treefmt.build.wrapper;
            help = "Format all files";
          }
          {
            package = pkgs.nix-tree;
            help = "Interactively browse dependency graphs of Nix derivations";
          }
          {
            package = pkgs.nvd;
            help = "Diff two nix toplevels and show which packages were upgraded";
          }
          {
            package = pkgs.nix-diff;
            help = "Explain why two Nix derivations differ";
          }
          {
            package = pkgs.nix-output-monitor;
            help = "Nix Output Monitor (a drop-in alternative for `nix` which shows a build graph)";
          }
          {
            package = config.packages.nix-flake-write;
            name = "nix-flake-write";
            help = "Regenerate flake.nix from the flake-file modules (nix run .#write-flake)";
          }
          {
            package = config.packages.nix-flake-update;
            name = "nix-flake-update";
            help = "Update flake inputs (gh access token; -e/--exclude INPUT to skip)";
          }
          {
            package = config.packages.nix-flake-build;
            name = "nix-flake-build";
            help = "Build or activate a host with nh (auto os/darwin/home; --switch, --on user@host)";
          }
          {
            package = config.packages.den-tree;
            name = "den-tree";
            help = "Print the Den aspect tree applied to each host and user";
          }
          {
            package = config.packages.sandvm;
            name = "sandvm";
            help = "Launch a sandboxed per-folder microVM (background by default; -f for foreground)";
          }
        ];

        devshell.startup.pre-commit.text = config.pre-commit.installationScript;
      };
    };
}
