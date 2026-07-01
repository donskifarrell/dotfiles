# apps/shell/search — fd / fzf / ripgrep / skim with sensible defaults.
# Ported from sini-nix modules/den/aspects/apps/shell/search.nix. Richer than
# the bare `enable`s in apps.cli (fd ignores, ripgrep args); the two merge
# harmlessly but this is the authoritative config. Integration scoped to fish.
{
  den.aspects.shell.bundles.search.homeManager = {
    programs = {
      fd = {
        enable = true;
        hidden = true;
        ignores = [
          ".Trash"
          ".git"
          "**/node_modules"
          "**/target"
        ];
        extraOptions = [ "--no-ignore-vcs" ];
      };

      fzf = {
        enable = true;
        enableFishIntegration = true;
        # HM now defaults nushell integration on and asserts fzf >= 0.73.0, but
        # nixpkgs 26.05 ships 0.72.0 and we use fish, not nushell. Opt out.
        enableNushellIntegration = false;
      };

      ripgrep = {
        enable = true;
        arguments = [
          "--smart-case"
          "--hidden"
          "--glob=!.git/*"
          "--max-columns=150"
          "--max-columns-preview"
        ];
      };
    };
  };
}
