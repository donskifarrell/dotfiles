# Common to Linux & darwin
# TODO: move to common folder and call using (self + /modules/shared/default.nix)?
{
  imports = [
    ../shared/i18n.nix
    ../shared/nix.nix
    ../shared/user.nix
  ];
}
