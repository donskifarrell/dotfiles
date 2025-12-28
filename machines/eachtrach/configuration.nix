{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [

  ];

  networking = {
    hostName = "eachtrach";

    firewall.allowedTCPPorts = [
      80
      443
    ];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    jq
    neovim
    inetutils
  ];

  systemd.tmpfiles.rules = [
    # Chroot root directories: must be root:root and not writable
    "d /srv 0755 root root - -"
    "d /srv/www 0755 root root - -"

    # Upload directory inside the chroot:
    # - owned by gh_deployer:web
    # - mode 02750 (rwx for owner, r-x for group, setgid so group stays web)
    "d /srv/www/site 02750 gh_deployer web - -"
  ];

  # Let caddy’s systemd unit see /srv/www/site despite hardening
  systemd.services.caddy.serviceConfig = {
    # Keep hardening, but allow read access to your content dir
    ReadOnlyPaths = lib.mkAfter [ "/srv/www/site" ];
    # If you *also* need Caddy to write there (usually not for static):
    # ReadWritePaths = lib.mkAfter [ "/srv/www/site" ];
  };

  # Group that both the deployer and Caddy share (readable by Caddy).
  users.groups.web = { };

  # SFTP-only deploy user; the key is restricted to the SFTP command & directory.
  users.users.gh_deployer = {
    isSystemUser = true;
    description = "SFTP-only deploy user";
    group = "web";
    extraGroups = [ "web" ];
    # No interactive shell
    shell = pkgs.shadow.outPath + "/bin/nologin";

    # Only this key can access; it's further constrained by the command+restrict options.
    openssh.authorizedKeys.keys = [
      "command=\"internal-sftp -d /site\",restrict ${
        config.clan.core.vars.generators.ssh-gh-deployer.files."ssh_gh_deployer_ed25519_key.pub".value
      }"
    ];
  };

  clan.core.vars.generators.ssh-gh-deployer = {
    files."ssh_gh_deployer_ed25519_key" = {
      secret = true;
      owner = "root";
      group = "root";
      mode = "0600";
    };
    files."ssh_gh_deployer_ed25519_key.pub" = {
      secret = false;
    };
    runtimeInputs = [ pkgs.openssh ];
    script = ''
      # Generate host key
      ssh-keygen -t ed25519 -N "" -C "gh-deployer-key" -f $out/ssh_gh_deployer_ed25519_key
    '';
  };

  services.openssh = {
    enable = true;

    hostKeys = [
      {
        path = config.clan.core.vars.generators.ssh-gh-deployer.files."ssh_gh_deployer_ed25519_key".path;
        type = "ed25519";
      }
    ];

    # Ensure scp uses the built-in SFTP server.
    settings."Subsystem" = "sftp internal-sftp";

    # Force internal-sftp to use a safe umask:
    #   umask 0027  -> dirs 0750, files 0640 (recommended: world has no read)
    # Chroot the deploy user into /srv/www and force SFTP (no shell).
    extraConfig = ''
      Match User gh_deployer
        ChrootDirectory /srv/www
        ForceCommand internal-sftp -d /site -u 0027
        X11Forwarding no
        AllowTcpForwarding no
        PermitTTY no
        PasswordAuthentication no
    '';
  };

  # Give Caddy read access to the files by putting it in the "web" group.
  # (The caddy user exists when services.caddy.enable = true)
  users.users.caddy.extraGroups = [ "web" ];
  services.caddy = {
    enable = true;

    # virtualHosts."localhost".extraConfig = ''
    #   respond "A test"
    # '';
    virtualHosts."localhost".extraConfig = ''
      root * /srv/www/site
      file_server
      encode zstd gzip
    '';

    # Static files, served directly by Caddy with auto-HTTPS
    virtualHosts."test.donalfarrell.com".extraConfig = ''
      # Serve the directory
      root * /srv/www/site/donalfarrell.com
      file_server
      encode zstd gzip

      # Good default caching for static assets (tweak as you like)
      @assets path *.css *.js *.png *.jpg *.jpeg *.gif *.svg *.ico *.webp *.woff *.woff2
      header @assets Cache-Control "public, max-age=31536000, immutable"
    '';
  };
}
