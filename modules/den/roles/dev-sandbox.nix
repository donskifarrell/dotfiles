# role-dev-sandbox — what a sandvm guest's user (iosta) gets, and nothing
# more: role-workstation's TUI shell environment (no graphical apps — no
# browsers/media/ghostty), git, the agent tooling, and the project-toolchain
# installers. A project's own dependencies come from its flake.nix/devenv.nix
# via devenv/direnv (plus the guest's boot-time pre-install in
# virtualisation/microvm-guest.nix), so no dev.lang.* here. herdr is the
# startup multiplexer — deliberately not shell.zellij.
{ den, ... }:
{
  den.aspects.roles.dev-sandbox = {
    includes = with den.aspects; [
      dev.git
      dev.git.github
      dev.git.lazygit

      dev.tools.devenv
      dev.tools.direnv
      dev.tools.herdr
      dev.tools.herdr.autostart

      apps.ai-tools

      shell
      shell.atuin
      shell.bat
      shell.delta
      shell.difftastic
      shell.eza
      shell.fish
      shell.neovim
      shell.starship
      shell.yazi
      shell.zoxide

      shell.bundles.archive
      shell.bundles.base
      shell.bundles.data
      shell.bundles.search
      shell.bundles.system
    ];

    # /workspace is the only project a sandbox ever has — trust its .envrc
    # without a manual `direnv allow` (allow-state lives in the guest's
    # ephemeral home, so it would be re-asked on every boot otherwise).
    homeManager.programs.direnv.config.whitelist.prefix = [ "/workspace" ];
  };
}
