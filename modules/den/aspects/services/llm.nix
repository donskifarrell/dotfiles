# Local LLM inference on abhaile's RX 9070 (RDNA4/gfx1201, 16GB VRAM).
#
# Full reference — benchmark numbers, what they mean per use case, parameter
# and model research, re-bench protocol: docs/llm.md. Summary of the on-box
# verdicts (2026-07-03, llama.cpp b9608): Vulkan beats ROCm on token
# generation (~+20% dense and MoE) → Vulkan serves; ROCm beats Vulkan on MoE
# prompt processing (~+50%) → ROCm binaries stay installed for prompt-heavy
# one-offs; Ollama measured slower than llama-server on identical weights →
# dropped; vLLM has no native RDNA4 kernels (vllm-project/vllm#28649) → not
# installed until that closes.
#
# Serving shape: ONE llama-server in router mode — clients pick a model via
# the OpenAI `model` field, models load on demand, at most one resident
# (models-max), so VRAM is bounded and idle after `systemctl restart`.
# Per-model placement (GPU layers / MoE experts on CPU) is left to
# llama-server's `--fit` auto-tuning: measured within noise of hand-tuned
# -ncmoe (tg ~51 t/s on Qwen3.6-35B Q4_K_M with 32k q8 KV) and it re-tunes
# itself when models, drivers, or the desktop's VRAM use change. Do NOT set
# n-gpu-layers/n-cpu-moe in the MoE presets — an explicit value aborts fit.
#
# Models live in /var/lib/llm/models (NOT $HOME): the service is a hardened
# DynamicUser unit with ProtectHome=true. df owns the dir for easy downloads.
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

        # Model data (ids, context sizes, per-model llama-server flags) lives
        # in _llm-models.nix — its own file because it used to have a second
        # consumer (a sandbox guest's generated agent models.yml) that had to
        # agree with it exactly.
        llm = import ./_llm-models.nix;
        inherit (llm) modelsDir;

        # Router presets: one INI section per model (keys = llama-server long
        # flags). Section name = the OpenAI API `model` id.
        presets = pkgs.writeText "llama-models-preset.ini" (
          lib.concatMapStringsSep "\n" (m: ''
            ${lib.concatMapStringsSep "\n" (l: "; " + l) (
              lib.splitString "\n" (lib.removeSuffix "\n" m.comment)
            )}
            [${m.id}]
            model = ${modelsDir}/${m.file}
            ctx-size = ${toString m.ctx}
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (
                k: v: "${k} = ${if k == "mmproj" then "${modelsDir}/${v}" else toString v}"
              ) m.flags
            )}
          '') llm.models
        );
      in
      {
        environment.systemPackages = lib.mapAttrsToList suffixed backends ++ [
          # llmfit: sizes GGUF models against this box's RAM/VRAM/CPU
          # (`llmfit system`, `llmfit list`, `llmfit recommend`) — the
          # picking-a-model half of docs/llm.md, which the model list below
          # is the picked half of. Pinned ahead of nixpkgs by the overlay.
          # pkgs.llmfit
        ];

        # Overlay pinning llmfit to its latest upstream release (nixpkgs lags
        # several point releases behind). Scoped to hosts including this
        # aspect; delete _llmfit.nix and this line once nixpkgs catches up.
        # nixpkgs.overlays = [ (import ./_llmfit.nix) ];

        systemd.tmpfiles.rules = [ "d ${modelsDir} 0755 df users -" ];

        # OpenAI-compatible API on 127.0.0.1:8080 (/v1/chat/completions,
        # /v1/models). `settings` is freeform → llama-server CLI flags.
        services.llama-cpp = {
          enable = true;
          package = backends.vulkan;
          settings = {
            models-preset = "${presets}";
            models-max = 1;
          };
        };
      };
  };
}
