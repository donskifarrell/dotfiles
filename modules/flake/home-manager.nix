# home-manager's flake-parts integration. Den drives each user's home-manager
# config through it, so it must be imported at the flake level.
{ inputs, ... }:
{
  imports = [ inputs.home-manager.flakeModules.home-manager ];
}
