# TODO: Migrate to just a home-manager module
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  user = config.me.username;
  homeDir = config.me.homeDir;

  # Maybe a better way to do this (e.g as a bundle?) but they don't change that much so it's fine.
  sshFiles = [
    # FF
    {
      dir = "ff";
      name = "ff-gh";
    }
    # Personal
    {
      dir = "df";
      name = "df-gh";
    }
    {
      dir = "df";
      name = "gt-ax6000";
    }
    {
      dir = "df";
      name = "belfast-vps";
    }
    # PgStar
    {
      dir = "pgstar";
      name = "pgstar-do-ideas";
    }
    {
      dir = "pgstar";
      name = "pgstar-gh";
    }
    # UF
    {
      dir = "uf";
      name = "uf-gh";
    }
    # Clan
    {
      dir = "clan";
      name = "braisle.clan";
    }
  ];
  addToSSHMap =
    map: file:
    map
    # Private Key
    // {
      "${file.name}" = {
        file = ../../shhhh/${file.dir}/${file.name}.age;
        path = "${homeDir}/.ssh/${file.dir}/${file.name}";
        owner = "${user}";
        mode = "600";
      };
    }
    # Corresponding Public Key
    // {
      "${file.name}.pub" = {
        file = ../../shhhh/${file.dir}/${file.name}.pub.age;
        path = "${homeDir}/.ssh/${file.dir}/${file.name}.pub";
        owner = "${user}";
        mode = "644";
      };
    };
in
{
  age.identityPaths = [ "${homeDir}/.ssh/df@secrets.nix" ];

  # SSH Keys
  age.secrets = builtins.foldl' addToSSHMap { } sshFiles // {
    # Configs
    "sshconfig.local" = {
      file = ../../shhhh/sshconfig.local.age;
      path = "${homeDir}/.ssh/sshconfig.local";
      owner = "${user}";
    };
    # Git
    "gitconfig.ff" = {
      file = ../../shhhh/git/gitconfig.ff.age;
      path = "${homeDir}/.config/git/gitconfig.ff";
      owner = "${user}";
    };
    "gitconfig.local" = {
      file = ../../shhhh/git/gitconfig.local.age;
      path = "${homeDir}/.config/git/gitconfig.local";
      owner = "${user}";
    };
    "gitconfig.pgstar" = {
      file = ../../shhhh/git/gitconfig.pgstar.age;
      path = "${homeDir}/.config/git/gitconfig.pgstar";
      owner = "${user}";
    };
    "gitconfig.uf" = {
      file = ../../shhhh/git/gitconfig.uf.age;
      path = "${homeDir}/.config/git/gitconfig.uf";
      owner = "${user}";
    };
    # Wireguard
    "belfast-asus-appletv" = {
      file = ../../shhhh/wg/belfast-asus-appletv.age;
      path = "${homeDir}/.ssh/wg/belfast-asus-appletv.conf";
      owner = "${user}";
    };
    "belfast-makati" = {
      file = ../../shhhh/wg/belfast-makati.age;
      path = "${homeDir}/.ssh/wg/belfast-makati.conf";
      owner = "${user}";
    };
    "belfast-manila" = {
      file = ../../shhhh/wg/belfast-manila.age;
      path = "${homeDir}/.ssh/wg/belfast-manila.conf";
      owner = "${user}";
    };
    "belfast-oneplus9" = {
      file = ../../shhhh/wg/belfast-oneplus9.age;
      path = "${homeDir}/.ssh/wg/belfast-oneplus9.conf";
      owner = "${user}";
    };
    # Clan SOPS keys
    "braisle-sops-keys" = {
      file = "../../shhhh/clan/keys.txt.age";
      path = "${homeDir}/.config/sops/age/keys.txt";
      owner = "${user}";
    }
  };
}
