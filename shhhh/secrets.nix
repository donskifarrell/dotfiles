let
  df = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMs4ZWWDVhhGphzt5qWlFJwdekbT8GZ642uKB6nig3k df@secrets.nix";
  users = [df];

  makati = "TODO";
  manila = "TODO";
  qemu = "TODO";
  systems = [makati manila qemu];
in {
  # Configs
  "./sshconfig.local.age".publicKeys = [df];
  "./git/.gitconfig.bnk.age".publicKeys = [df];
  "./git/.gitconfig.ff.age".publicKeys = [df];
  "./git/.gitconfig.local.age".publicKeys = [df];
  "./git/.gitconfig.pgstar.age".publicKeys = [df];
  "./git/.gitconfig.uf.age".publicKeys = [df];

  # FF
  "./ff/ff-gh.age".publicKeys = [df];
  "./ff/ff-gh.pub.age".publicKeys = [df];

  # Personal
  "./df/df-gh.age".publicKeys = [df];
  "./df/df-gh.pub.age".publicKeys = [df];
  "./df/gt-ax6000.age".publicKeys = [df];
  "./df/gt-ax6000.pub.age".publicKeys = [df];
  "./df/belfast-vps.age".publicKeys = [df];
  "./df/belfast-vps.pub.age".publicKeys = [df];

  # PgStar
  "./pgstar/pgstar-do-ideas.age".publicKeys = [df]; # DigitalOcean
  "./pgstar/pgstar-do-ideas.pub.age".publicKeys = [df];
  "./pgstar/pgstar-gh.age".publicKeys = [df];
  "./pgstar/pgstar-gh.pub.age".publicKeys = [df];

  # UF
  "./uf/uf-gh.age".publicKeys = [df];
  "./uf/uf-gh.pub.age".publicKeys = [df];

  # Wireguard
  "./wg/belfast-asus-appletv.age".publicKeys = [df];
  "./wg/belfast-manila.age".publicKeys = [df];

  # Work
  "./bnk/bnk-drc-df.age".publicKeys = [df];
  "./bnk/bnk-drc-df.pub.age".publicKeys = [df];
  "./bnk/bnk-do-df.age".publicKeys = [df];
  "./bnk/bnk-do-df.pub.age".publicKeys = [df];
  "./bnk/bnk-gitea-df.age".publicKeys = [df];
  "./bnk/bnk-gitea-df.pub.age".publicKeys = [df];
}
