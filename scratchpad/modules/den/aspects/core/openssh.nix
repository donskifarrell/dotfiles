# Ported from modules/system/openssh.nix
{
  den.aspects.core.openssh.nixos = _: {
    services.openssh = {
      enable = true;
      openFirewall = true;
    };

    programs.ssh.startAgent = true;
  };
}
