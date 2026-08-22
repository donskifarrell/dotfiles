# Ported from modules/home/atuin.nix. Shell history sync (fish integration).
{
  den.aspects.shell.atuin.homeManager = {
    programs.atuin = {
      enable = true;
      enableFishIntegration = true;
      daemon.enable = true;
      flags = [ "--disable-up-arrow" ];
    };

    # Atuin owns Ctrl-R. shell.bundles.search enables programs.fzf, whose fish
    # integration binds Ctrl-R too — home-manager warns about the clash on
    # every eval. Atuin's init is sourced last and already won in practice, so
    # this only removes a binding that was being overwritten anyway. Empty
    # command = FZF_CTRL_R_COMMAND="", the supported way to yield Ctrl-R to a
    # history manager (needs fzf >= 0.66; nixpkgs has 0.74). Lives here, not in
    # the search bundle, so a host that takes fzf without atuin keeps fzf's
    # Ctrl-R. (fzf's Ctrl-T / Alt-C are untouched.)
    programs.fzf.historyWidget.command = "";
  };
}
