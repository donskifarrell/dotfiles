# Obsidian + the ~/vaults/main vault (ideation / finance / todos; drop/ is the
# AI-agent exchange folder — full architecture + manual steps: docs/obsidian.md).
#
# HM only REGISTERS the vault (an entry in ~/.config/obsidian/obsidian.json,
# merged by the module's activation script). Deliberately NO defaultSettings /
# vault settings: those would materialise as nix-store symlinks inside the
# vault's .obsidian/, which Syncthing cannot represent on Android and which
# would fight the synced .obsidian dir. Community plugins (obsidian-git) are
# installed once via Obsidian's own plugin browser as real files and then
# travel as ordinary vault content to the other devices.
#
# Portable: the HM module handles darwin config paths (future MacBook).
{
  den.aspects.apps.obsidian.homeManager = {
    programs.obsidian = {
      enable = true;
      vaults."vaults/main" = { }; # target defaults to the attr name, relative to $HOME
    };
  };
}
