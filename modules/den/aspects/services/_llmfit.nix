# nixpkgs overlay: pin `llmfit` to the latest upstream release.
#
# NOT auto-imported (leading `_`, like _llm-models.nix) — it is an overlay
# function, not a flake-parts module. Applied by services/llm.nix.
#
# llmfit (github:AlexsJones/llmfit) is a Rust TUI that sizes GGUF models
# against the box's RAM/VRAM/CPU. nixpkgs carries it, but lags: the FlakeHub
# weekly locked here has 1.1.8 while upstream is at 1.1.12. Only version +
# hashes ever change between releases (cf. NixOS/nixpkgs#556371), so this
# overrides the nixpkgs derivation rather than forking its expression —
# dependencies, meta and the updateScript keep coming from nixpkgs, and
# `meta.changelog` re-resolves through the fixpoint to the pinned tag.
#
# `cargoDeps` has to be rebuilt by hand: buildRustPackage reads `cargoHash`
# off `args`, not `finalAttrs` (pkgs/build-support/rust/build-rust-package,
# `hash = args.cargoHash;`), so overriding `cargoHash` via overrideAttrs is
# silently ignored — the vendor fetch would keep the 1.1.8 hash against 1.1.12
# sources and fail. Overriding `cargoDeps` itself is what takes effect.
#
# To bump (or to DELETE this file once nixpkgs >= the version you want —
# check with `nix eval .#nixosConfigurations.abhaile.pkgs.llmfit.version`):
#   1. version = "<new>";
#   2. src hash:
#        nix-prefetch-url --unpack \
#          https://github.com/AlexsJones/llmfit/archive/refs/tags/v<new>.tar.gz
#        nix hash convert --hash-algo sha256 --to sri <base32 from above>
#   3. cargo hash: set it to lib.fakeHash, build, take the "got:" value from
#      the mismatch error.
final: prev: {
  llmfit = prev.llmfit.overrideAttrs (
    finalAttrs: _prevAttrs: {
      version = "1.1.12";

      src = final.fetchFromGitHub {
        owner = "AlexsJones";
        repo = "llmfit";
        tag = "v${finalAttrs.version}";
        hash = "sha256-JUlCHA/KM9M/71a2XCVIq5+5O43bvceXFxWwSaA6Qak=";
      };

      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        hash = "sha256-lSRMhQChBTXyPbFwGH2u0okKu3zHvAGX6NvXB0/wLC0=";
      };
    }
  );
}
