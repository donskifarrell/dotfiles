# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)

{ inputs, lib, config, pkgs, ... }: {
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors), use something like:
    # inputs.nix-colors.homeManagerModule

    # Feel free to split up your configuration and import pieces of it here.
    ./home-base.nix
    
    "${fetchTarball {
      url = "https://github.com/msteen/nixos-vscode-server/tarball/master";
      sha256 = "1cszfjwshj6imkwip270ln4l1j328aw2zh9vm26wv3asnqlhdrak";
    }}/modules/vscode-server/home.nix"
  ];

  services.vscode-server.enable = true;
  
  # Nicely reload system units when changing configs
  # systemd.user.startServices = "sd-switch";
}