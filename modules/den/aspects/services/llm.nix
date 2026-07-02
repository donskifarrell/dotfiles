# Local LLM inference on abhaile's RX 9070 (RDNA4/gfx1201, 16GB VRAM).
#
# Both llama.cpp GPU backends are installed side by side as suffixed binaries
# (llama-{server,bench,cli}-vulkan / -rocm) so backends can be A/B-tested
# per-invocation without a rebuild. The default serving runtime is chosen by
# on-box llama-bench numbers, NOT by published benchmarks — RDNA4 ROCm/Vulkan
# performance shifts with every ROCm/mesa/kernel bump, so re-bench after
# `nix flake update` (see TODO.md).
#
# BENCHMARK 2026-07-03 (llama.cpp b9190, ROCm 7.2.1, mesa 26.1.2 RADV, kernel
# 6.18.35, -dev {Vulkan0,ROCm0} = dGPU, fa=1, best-of shown):
#
#   Llama-3.1-8B-Instruct Q4_K_M (fits VRAM, ~5GiB weights):
#     vulkan  pp512 3160 t/s   tg128 108.6 t/s   <- winner (tg +24%)
#     rocm    pp512 3284 t/s   tg128  87.8 t/s
#     ollama-vulkan (API)  pp ~1950   tg ~102     (0.30.6, same GGUF)
#     ollama-rocm   (API)  pp ~1640   tg ~65-73
#     llama-server-vulkan (API, this config): pp ~3180  tg ~107
#   Qwen3-30B-A3B-Instruct-2507 Q4_K_M (17.3GiB > VRAM; -ncmoe 12):
#     vulkan  pp512  813 t/s   tg128 38.6 t/s    <- tg winner
#     rocm    pp512 1326 t/s   tg128 34.2 t/s    <- pp winner (use -rocm
#                                                   binaries for prompt-heavy
#                                                   MoE offload work)
#
# Verdict: llama-server + Vulkan default (fastest generation, leanest);
# Ollama measurably slower at same weights, vLLM skipped (RDNA4 kernel gap
# still open upstream, vllm-project/vllm#28649).
#
# Models live in /var/lib/llm/models (NOT $HOME): the nixpkgs llama-cpp
# service is a hardened DynamicUser unit with ProtectHome=true, so it cannot
# read models from /home. df owns the dir for easy `curl -o` downloads.
{
  den.aspects.services.llm = {
    nixos =
      { pkgs, lib, ... }:
      let
        backends = {
          vulkan = pkgs.llama-cpp-vulkan;
          rocm = pkgs.llama-cpp-rocm;
        };
        tools = [
          "llama-server"
          "llama-bench"
          "llama-cli"
        ];
        # Suffix the CLI names so both backends can sit in systemPackages
        # without binary collisions.
        suffixed =
          suffix: pkg:
          pkgs.runCommand "llama-cpp-${suffix}-suffixed" { } ''
            mkdir -p $out/bin
            ${lib.concatMapStringsSep "\n" (t: "ln -s ${pkg}/bin/${t} $out/bin/${t}-${suffix}") tools}
          '';
      in
      {
        environment.systemPackages = lib.mapAttrsToList suffixed backends;

        systemd.tmpfiles.rules = [ "d /var/lib/llm/models 0755 df users -" ];

        # OpenAI-compatible API on 127.0.0.1:8080 (/v1/chat/completions).
        # Holds ~6GiB VRAM while running: `systemctl stop llama-cpp` frees it.
        #
        # NB: NixOS modules come from `inputs.nixpkgs` (older than the
        # `nixpkgs-unstable` the packages come from), so this is the
        # extraFlags-style llama-cpp module; newer nixpkgs folds all of these
        # into a freeform `settings` attrset — migrate when inputs.nixpkgs
        # catches up.
        services.llama-cpp = {
          enable = true;
          package = backends.vulkan;
          model = "/var/lib/llm/models/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf";
          extraFlags = [
            # pin the dGPU; Vulkan1 is the Raphael iGPU
            "--device"
            "Vulkan0"
            "-ngl"
            "99"
            "--flash-attn"
            "on"
            "--ctx-size"
            "16384"
            # proper chat-template handling for /v1 API
            "--jinja"
          ];
        };
      };
  };
}
