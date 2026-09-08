# Shared data: the models abhaile's llama-server router serves.
#
# Underscore-prefixed so import-tree skips it — this is a plain attribute set
# imported by hand, not a flake-parts module. One consumer:
#
#   services/llm.nix   builds llama-server's router preset INI (one section
#                      per model).
#
# It used to have a second (virtualisation/microvm-guest.nix generated omp's
# `local` provider models.yml from it); that went with omp on 2026-09-08.
# `id` is the OpenAI-API model id (the INI section name) an agent asks for;
# `ctx` is the server-side context window.
{
  modelsDir = "/var/lib/llm/models";

  models = [
    {
      id = "llama-3.1-8b";
      name = "Llama 3.1 8B Instruct (abhaile llama-server)";
      file = "Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf";
      ctx = 16384;
      maxTokens = 4096;
      # Not usable as a coding-agent backend at this ctx: an agent harness's
      # overhead measured ~17.1k tokens, over this model's 16k ctx, so every
      # request spent ~400s before failing. Raise `ctx` here (VRAM cost: the
      # KV cache roughly doubles, so re-bench the fast lane) to change that.
      comment = "fast lane: scraping/extraction/file-org (108 t/s, fully in VRAM)";
      flags = {
        device = "Vulkan0";
        n-gpu-layers = 99;
        flash-attn = "on";
        jinja = "on";
      };
    }
    {
      id = "qwen3.6-35b-a3b";
      name = "Qwen3.6 35B A3B (abhaile llama-server)";
      file = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
      ctx = 65536;
      maxTokens = 8192;
      comment = ''
        quality lane: coding + document/financial analysis (~51 t/s at
        32k; fit offloads experts to CPU as the q8 KV cache grows — 64k
        ctx costs some tg speed). Hybrid thinking is OFF by default —
        measured 2.5k+ hidden tokens (~50s) before any answer; re-enable
        per request with "chat_template_kwargs":{"enable_thinking":true}.'';
      flags = {
        device = "Vulkan0";
        flash-attn = "on";
        cache-type-k = "q8_0";
        cache-type-v = "q8_0";
        jinja = "on";
        reasoning = "off";
        mmproj = "mmproj-Qwen3.6-35B-A3B-F16.gguf";
      };
    }
  ];

  # Where a sandbox guest reaches abhaile's llama-server: qemu's SLIRP gateway
  # is the host's loopback, and the service binds 127.0.0.1:8080. Nothing in
  # this repo generates guest agent config from it any more (see the header) —
  # it is the value to point a guest-side agent at by hand.
  guestBaseUrl = "http://10.0.2.2:8080/v1";
}
