{
  inputs,
  pkgs,
  ...
}: {
  programs = {
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      # systemdIntegration = true;
      xwayland.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    # xdg-desktop-portal-hyprland
    qt6.qtwayland
    qt6.qt5compat
    libsForQt5.qt5.qtwayland
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qtsvg
    libsForQt5.qt5.qtquickcontrols2
    nwg-look
  ];
}
