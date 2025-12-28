# See /modules/darwin/* for actual settings
# This file is just *top-level* configuration.
{ flake, pkgs, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;

  username = "df";
in
{
  imports = [
    (self + /modules/flake-parts/config.nix)

    inputs.agenix.nixosModules.default
    inputs.home-manager.darwinModules.home-manager

    (self + /modules/shared/agenix.nix)
    (self + /modules/shared/fonts.nix)
    (self + /modules/shared/nix.nix)
    (self + /modules/shared/user.nix)

    self.darwinModules.system
    self.darwinModules.homebrew
  ];

  system.primaryUser = "df";

  # activationScripts are executed every time you boot the system or run `nixos-rebuild` / `darwin-rebuild`.
  #  system.activationScripts.postUserActivation.text = ''
  # activateSettings -u will reload the settings from the database and apply them to the current session,
  # so we do not need to logout and login again to make the changes take effect.
  #    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  #  '';
  system.activationScripts.postActivation.text = ''
    echo "setting up users' shells..." >&2
    dscl . create /Users/${username} UserShell "/etc/profiles/per-user/${username}/bin/fish"
  '';

  nixpkgs.hostPlatform = "aarch64-darwin";
  networking.hostName = "iompar";
  networking = {
    knownNetworkServices = [
      "Wi-Fi"
      "Thunderbolt Bridge"
      "osx"
    ];
    dns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  # Add ability to used TouchID for sudo authentication
  security.pam.services.sudo_local.touchIdAuth = true;

  programs.fish.enable = true;
  environment.shells = [
    pkgs.fish
  ];

  # For home-manager to work.
  # https://github.com/nix-community/home-manager/issues/4026#issuecomment-1565487545
  # Common config is in modules/shared/user.nix
  users.users."${username}".home = "/Users/${username}";

  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
    };

    # Automatically move old dotfiles out of the way
    #
    # Note that home-manager is not very smart, if this backup file already exists it
    # will complain "Existing file .. would be clobbered by backing up". To mitigate this,
    # we try to use as unique a backup file extension as possible.
    backupFileExtension = "nix-old-bk";

    # Enable home-manager for "runner" user
    users."${username}" = {
      imports = [
        (self + /modules/flake-parts/config.nix)

        inputs.nix-index-database.hmModules.nix-index
        (self + /configurations/home/${username}.nix)
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    git
    nixfmt-rfc-style
  ];

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # https://github.com/nix-darwin/nix-darwin/issues/1346
  # https://github.com/nix-darwin/nix-darwin/issues/1339
  ids.gids.nixbld = 350;
}
