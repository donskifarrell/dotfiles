# `sandvm` is this flake's own package (pkgs/by-name/sandvm), not a nixpkgs
# attribute — there's no overlay merging pkgs/by-name into the nixpkgs
# instance NixOS/home-manager modules see, so it has to be referenced via
# `inputs.self.packages`, the same way modules/flake-parts/devshell.nix
# reaches pkgs/by-name packages via `config.packages.<name>` in the
# flake-parts (not module-system) context.
#
# (Named `sandvm`, not `devbox`: nixpkgs already has an unrelated package
# literally called `devbox` — Jetify's tool — which `pkgs.devbox` would have
# silently resolved to instead.)
{ inputs, ... }:
{
  den.aspects.dev.tools.sandvm = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.sandvm ];

        # SSH-agent forwarding into sandboxes (git push/pull auth without any
        # key material in the guest — the agent only ever *signs* on the
        # guest's behalf, over the live connection). It must live HERE, not in
        # the per-instance blocks the wrapper writes into ~/.ssh/config.d/:
        # ssh_config is first-match-wins per keyword, and core.network.ssh's
        # `Host *` sets `ForwardAgent no` *before* the `Include
        # ~/.ssh/config.d/*` line — anything in those files is shadowed. This
        # block instead rides home-manager's guarantee that non-"*" settings
        # blocks render before the "*" default block, so it wins.
        programs.ssh.settings."sandvm-*".ForwardAgent = true;
      };
  };
}
