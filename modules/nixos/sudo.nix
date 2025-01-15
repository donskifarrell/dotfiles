{ config, ... }:
{
  security.sudo.extraRules = [
    {
      users = [ config.me.username ];
      commands = [
        {
          command = "/etc/profiles/per-user/${config.me.username}/bin/nh";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
