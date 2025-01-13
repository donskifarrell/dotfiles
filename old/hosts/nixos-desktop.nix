{
  inputs,
  pkgs,
  ssh-keys,
  ...
}:
let
  user = "df";
  hostname = "abhaile";
  system = "x86_64-linux";
  homeDir =
    if pkgs.stdenv.isLinux then
      "/home/${user}"
    else if pkgs.stdenv.isDarwin then
      "/Users/${user}"
    else
      throw "Unsupported platform";
in
{
  _module.args = {
    inherit
      user
      hostname
      system
      homeDir
      ;
  };

  services.journald.rateLimitBurst = 50000;
  services.journald.rateLimitInterval = "1s";
  services.journald.extraConfig = ''
    Storage=persistent
  '';
  services.sysstat.enable = true;

  services = {
    # dbus.enable = true;

    # TODO: what is this option?
    # udiskie.enable = true; # Auto mount devices

    # TODO: media keys
    # playerctld.enable = true;
  };

  virtualisation.libvirtd.enable = true;
  virtualisation.podman.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    "${user}" = {
      isNormalUser = true;
      initialHashedPassword = "";
      description = "${user}@${hostname}";
      extraGroups = [
        "docker"
        "libvirtd"
        "networkmanager"
        "wheel" # Enable ‘sudo’ for the user.
      ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = ssh-keys;
    };

    root = {
      openssh.authorizedKeys.keys = ssh-keys;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    # useUserPackages = true; # If enabled, then home-manager apps aren't linked properly to /Users/X/.nix-profile/..
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${user} =
      { pkgs, ... }:
      {
        _module.args = {
          inherit user hostname system;
        };

        imports = [
          ./home-manager
          ./home-manager/alacritty.nix
          ./home-manager/btop.nix
          ./home-manager/fish.nix
          ./home-manager/git.nix
          ./home-manager/neovim.nix
          ./home-manager/ssh.nix
          ./home-manager/starship.nix
          ./home-manager/tmux.nix
          ./home-manager/vscode.nix

          ./home-manager/electron.nix
          # ./home-manager/gtk.nix
        ];

        home.homeDirectory = pkgs.lib.mkForce "/home/${user}";

        home.packages =
          let
            pkgSets = import ./home-manager/packages.nix { inherit pkgs inputs; };
          in
          pkgSets.essentials-utils
          ++ pkgSets.essentials-dev
          ++ pkgSets.essentials-gui
          ++ pkgSets.essentials-x86-gui
          ++ pkgSets.nixos
          ++ pkgSets.nixos-gnome;

        home = {
          file."gnome-scratchpad" = {
            source = "/home/${user}/.dotfiles/hosts/config/gnome-scratchpad";
            target = "/home/${user}/.config/gnome-scratchpad";
          };
        };
      };
  };

  environment.systemPackages = [
    pkgs.archiver
    pkgs.curl
    pkgs.foot
    pkgs.gitAndTools.gitFull
    pkgs.inetutils
    pkgs.libinput
    pkgs.libnotify
    pkgs.micro
    pkgs.p7zip
    pkgs.wev
    pkgs.wlr-randr
  ];
}
