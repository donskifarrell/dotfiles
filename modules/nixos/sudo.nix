{ flake, ... }:
{
  security.sudo.extraRules = [
    {
      users = [ flake.config.me.username ];
      commands = [
        {
          command = "/etc/profiles/per-user/${flake.config.me.username}/bin/nh";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
