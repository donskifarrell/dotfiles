{ flake, ... }:
{
  security.sudo.extraRules = [
    {
      users = [ flake.config.me.username ];
      commands = [
        {
          command = "nh";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
