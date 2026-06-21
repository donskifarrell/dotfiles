#!/usr/bin/env bash
# Live-deploy the running build-vm `short` without rebooting it.
#
# A `build-vm` keeps itself alive with VM-only mount units (nix-store.mount, the
# tmp-shared/tmp-xchg 9p shares). The *plain* system.build.toplevel that
# `nixos-rebuild --target-host` pushes lacks those, so activation stops them and
# wedges the VM. So we push the *vmVariant* toplevel instead (same mounts) and
# activate with `switch-to-configuration test` (no bootloader install).
#
# Usage: edit -> ./vm-deploy.sh   (VM must be running via ./result/bin/run-short-vm)
set -euo pipefail

cd "$(dirname "$0")"
git add -A   # Nix can't see untracked files inside the parent .dotfiles repo

attr='.#nixosConfigurations.short.config.virtualisation.vmVariant.system.build.toplevel'
echo "==> building"
top=$(nix build --no-link --print-out-paths "$attr")

export NIX_SSHOPTS="-p 2222 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
echo "==> copying closure to VM"
nix-copy-closure --to root@localhost "$top"

echo "==> activating (test)"
# shellcheck disable=SC2086
ssh $NIX_SSHOPTS root@localhost "$top/bin/switch-to-configuration test"
echo "==> done"
