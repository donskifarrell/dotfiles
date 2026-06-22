# apps/dev/security/gpg — GnuPG with a hardened gpg.conf and a caching
# gpg-agent (for commit signing / decryption). Ported from sini-nix
# modules/den/aspects/apps/dev/security/gpg.nix.
#
# Adaptations for this setup:
#   - sini's `homeLinux`/`persistHome` quirks are folded in / dropped (the
#     scratchpad uses the upstream den classes only).
#   - `enableSshSupport = false`: df already runs a dedicated ssh-agent
#     (apps/dev/ssh), so gpg-agent must NOT also claim SSH_AUTH_SOCK.
#   - pinentry is pinentry-gnome3 (df runs GNOME).
{
  den.aspects.core.security.gpg = {
    nixos = {
      services.pcscd.enable = true; # smartcard daemon (YubiKey, etc.)
      hardware.gpgSmartcards.enable = true;
    };

    homeManager =
      { pkgs, ... }:
      {
        programs.gpg = {
          enable = true;

          scdaemonSettings.disable-ccid = true;

          settings = {
            personal-cipher-preferences = "AES256 AES192 AES";
            personal-digest-preferences = "SHA512 SHA384 SHA256";
            personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
            default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
            cert-digest-algo = "SHA512";
            s2k-digest-algo = "SHA512";
            s2k-cipher-algo = "AES256";
            charset = "utf-8";
            fixed-list-mode = true;
            no-comments = true;
            no-emit-version = true;
            keyid-format = "0xlong";
            list-options = "show-uid-validity";
            verify-options = "show-uid-validity";
            with-fingerprint = true;
            require-cross-certification = true;
            no-symkey-cache = true;
            use-agent = true;
            throw-keyids = true;
          };
        };

        services.gpg-agent = {
          enable = true;

          # SSH is handled by the dedicated ssh-agent.
          enableSshSupport = false;

          enableBashIntegration = true;
          enableFishIntegration = true;

          pinentry.package = pkgs.pinentry-gnome3;

          defaultCacheTtl = 43200;
          maxCacheTtl = 86400;

          extraConfig = ''
            ttyname $GPG_TTY
          '';
        };
      };
  };
}
