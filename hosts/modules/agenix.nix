{
  homeDir,
  user,
  ...
}: let
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
    # Work
    {
      dir = "bnk";
      name = "bnk-drc-df";
    }
    {
      dir = "bnk";
      name = "bnk-do-df";
    }
    {
      dir = "bnk";
      name = "bnk-gitea-df";
    }
  ];
  addToSSHMap = map: file:
    map
    # Private Key
    // {
      "${file.name}" = {
        file = ../../shhhh/${file.dir}/${file.name}.age;
        path = "${homeDir}/.ssh/${file.dir}/${file.name}";
        owner = "${user}";
      };
    }
    # Corresponding Public Key
    // {
      "${file.name}.pub" = {
        file = ../../shhhh/${file.dir}/${file.name}.pub.age;
        path = "${homeDir}/.ssh/${file.dir}/${file.name}.pub";
        owner = "${user}";
      };
    };
in {
  age.identityPaths = ["${homeDir}/.ssh/df@secrets.nix"];

  # SSH Keys
  age.secrets =
    builtins.foldl' addToSSHMap {} sshFiles
    // {
      # Configs
      "sshconfig.local" = {
        file = ../../shhhh/sshconfig.local.age;
        path = "${homeDir}/.ssh/sshconfig.local";
        owner = "${user}";
      };
      # Git
      ".gitconfig.bnk" = {
        file = ../../shhhh/git/.gitconfig.bnk.age;
        path = "${homeDir}/.config/git/.gitconfig.bnk";
        owner = "${user}";
      };
      ".gitconfig.ff" = {
        file = ../../shhhh/git/.gitconfig.ff.age;
        path = "${homeDir}/.config/git/.gitconfig.ff";
        owner = "${user}";
      };
      ".gitconfig.local" = {
        file = ../../shhhh/git/.gitconfig.local.age;
        path = "${homeDir}/.config/git/.gitconfig.local";
        owner = "${user}";
      };
      ".gitconfig.pgstar" = {
        file = ../../shhhh/git/.gitconfig.pgstar.age;
        path = "${homeDir}/.config/git/.gitconfig.pgstar";
        owner = "${user}";
      };
      ".gitconfig.uf" = {
        file = ../../shhhh/git/.gitconfig.uf.age;
        path = "${homeDir}/.config/git/.gitconfig.uf";
        owner = "${user}";
      };
      # Wireguard
      "belfast-asus-appletv" = {
        file = ../../shhhh/wg/belfast-asus-appletv.age;
        path = "${homeDir}/.ssh/wg/belfast-asus-appletv.conf";
        owner = "${user}";
      };
      "belfast-manila" = {
        file = ../../shhhh/wg/belfast-manila.age;
        path = "${homeDir}/.ssh/wg/belfast-manila.conf";
        owner = "${user}";
      };
    };
}
