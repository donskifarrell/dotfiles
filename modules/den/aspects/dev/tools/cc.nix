# dev.tools.cc — the C/C++ toolchain a *native addon build* needs, on df's
# PATH. Not a language aspect: nothing here is for writing C. It exists so the
# escape hatch that npm/pip/gem packages fall back to when no prebuilt binary
# matches this platform doesn't dead-end.
#
# The failure it fixes is opaque from the package manager's side. `pi install
# npm:@plannotator/pi-extension` (2026-09-02) pulled node-pty, whose
# scripts/prebuild.js found no prebuilds/linux-x64 in the tarball and fell back
# to `node-gyp rebuild`, which died on `Error: not found: make`. node-gyp had
# already resolved python3 and the node headers out of the nixpkgs nodejs-slim
# store path — only the toolchain was missing. Distros where these packages
# "just work" have build-essential pulled in by something; NixOS ships no
# global cc, so every such install fails here and nowhere else.
#
# Why in the profile rather than a one-off `nix shell nixpkgs#gnumake #gcc`:
# the addon that gets compiled keeps an rpath into whichever gcc built it. From
# an ad-hoc shell that store path is not a GC root, so the next
# `nix-collect-garbage -d` breaks the extension at runtime, long after the
# install, with a missing-libstdc++ error that points nowhere useful. In
# home.packages it is rooted for as long as the generation lives.
#
# roles.sandbox.dev installs the same set on the nixos side for the same reason
# ("a `pip install`/`npm rebuild` that drops to C doesn't dead-end") — kept
# separate because a guest wants it in systemPackages, not in iosta's profile.
#
# Trade-off worth knowing: with cc on PATH a project that builds only because
# of these packages *looks* like it builds anywhere, and its devenv.nix/
# flake.nix never grows the toolchain input it actually needs. Per-project
# toolchains still belong in devenv.nix — same rationale as dev.lang.python and
# dev.lang.node. This is the fallback under them, not a substitute.
{
  den.aspects.dev.tools.cc.homeManager =
    { pkgs, ... }:
    {
      home.packages = [
        pkgs.gnumake
        # The wrapper, not bare `gcc`: it is what puts a working `cc`/`g++` on
        # PATH with the glibc/binutils flags Nix needs baked in.
        pkgs.stdenv.cc
        # gyp's make generator drives the linker through gcc, but static_library
        # intermediates call $(AR) directly — ar/ranlib/strip come from here.
        pkgs.binutils
        # Sniffed by node-gyp/setuptools/cargo build scripts for system libs.
        pkgs.pkg-config
      ];
    };
}
