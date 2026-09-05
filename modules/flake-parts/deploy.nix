# deploy-rs — day-2 remote deploys: `deploy .#<host>` from the devshell.
# Builds run locally (abhaile) and the closure is pushed over ssh; magic
# rollback reverts a deploy that breaks its own ssh connectivity — exactly
# the lockout failure mode that matters for a remote VPS (eachtrach).
#
# Every Den-emitted nixosConfiguration except the `scoite-*` guest templates
# (not real machines — imperatively launched by the `scoite` CLI) becomes a
# deploy node. Node hostname = the bare host name: services.tailscale's
# /etc/hosts alias sync makes that resolve tailnet-wide, so deploys ride
# tailscale with no extra DNS. Provisioning a brand-new box is nixos-anywhere's
# job, not this file's (its kexec path takes over a stock Ubuntu VPS image).
#
# History worth keeping (2026-09-04/05): eachtrach briefly needed a per-host
# override to its public ip, because Tailscale SSH intercepted port 22 on the
# tailnet and gated it behind an interactive browser check that hangs a
# non-interactive `deploy`. That is fixed at the source instead —
# `services.tailscale.no-ssh` on the host — so the bare name works again. If a
# future host ever needs a different transport, reintroduce a
# `deployHost = { <host> = "<addr>"; }` lookup and use
# `hostname = deployHost.${name} or name`. The one real argument for the public
# ip was that it is not the tunnel a bad deploy to the *exit node* could take
# down; magic rollback covers that case, and the public ip stays available
# manually.
{
  inputs,
  lib,
  config,
  ...
}:
{
  flake-file.inputs.deploy-rs = {
    url = "github:serokell/deploy-rs";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  flake.deploy.nodes = lib.mapAttrs (name: cfg: {
    hostname = name;
    profiles.system = {
      sshUser = "root";
      user = "root";
      path = inputs.deploy-rs.lib.${cfg.pkgs.stdenv.hostPlatform.system}.activate.nixos cfg;
    };
    # Prefix filter, not a name list: the guest hosts are `scoite-minimal`,
    # `scoite-dev`, … so the old `removeAttrs [ "sandvm" ]` matched nothing
    # and quietly turned every sandbox tier into a deploy node (and into a
    # deployChecks target, re-evaluating all of them on `nix flake check`).
  }) (lib.filterAttrs (name: _: !lib.hasPrefix "scoite-" name) config.flake.nixosConfigurations);

  perSystem =
    { system, ... }:
    {
      # deploy-rs's schema + activatable checks. Side effect: `nix flake
      # check` now evaluates every deploy node's toplevel again — a partial
      # restore of the lost per-host checks (TODO item 5).
      checks = inputs.deploy-rs.lib.${system}.deployChecks inputs.self.deploy;
    };
}
