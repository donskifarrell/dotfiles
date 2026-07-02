# modules/den/aspects/secrets/sops.nix
#
# Base sops-nix aspect: decryption WIRING only, no secrets. Include it on every
# host that consumes any sops secret; the secrets themselves are declared next
# to their consumers (secrets/home.nix, secrets/<host>.nix, services/*.nix).
#
# Host identity = the machine's own /etc/ssh/ssh_host_ed25519_key (via
# age.sshKeyPaths). Nothing to provision: a freshly-installed host has the key
# after first boot. This is the anti-lockout choice — the host recipient in
# .sops.yaml is `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`.
{ inputs, ... }:
{
  den.aspects.secrets.sops.nixos = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # Decrypt using the host's existing SSH host key (age, ed25519).
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    # Age is the only method; drop sops-nix's default gnupg-via-rsa fallback so
    # activation doesn't depend on /etc/ssh/ssh_host_rsa_key or attempt GPG.
    sops.gnupg.sshKeyPaths = [ ];
  };
}
