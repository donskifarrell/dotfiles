# Local LLM inference on abhaile

RX 9070 (RDNA4/gfx1201, 16GB VRAM) + Ryzen 7 7700X (8c/16t) + 62GB RAM. Config lives in
`modules/den/aspects/services/llm.nix` (+ `hardware/gpu/rocm.nix` diagnostics); this doc holds the benchmark numbers,
the reasoning, and the parameter/model research so decisions can be re-derived when the stack moves.

## Current setup

- **Runtime**: llama.cpp `llama-server`, **Vulkan (RADV) backend** — won on-box benchmarks (below).
- **Endpoint**: OpenAI-compatible API on `127.0.0.1:8080` (`/v1/chat/completions`, `/v1/models`).
- Both llama.cpp backends installed side by side as `llama-{server,bench,cli}-vulkan` / `-rocm` — A/B test
  per-invocation, no rebuild.
- Models in `/var/lib/llm/models` (df-owned; NOT `$HOME` — the service is DynamicUser + ProtectHome).
- Device 0 = RX 9070, device 1 = Raphael iGPU in both stacks — always pin (`--device Vulkan0` / `-dev ROCm0`).

## What the benchmark numbers mean (in terms of real use)

Two numbers matter, and they map directly onto different workloads:

- **pp** (prompt processing, t/s) — how fast the model _reads input_. This dominates anything that feeds the model large
  text: **document analysis, financial statement review, web-page extraction, big code files**. At pp=2600 t/s, a
  50-page document (~25k tokens) is ingested in ~10s; at pp=800, ~30s.
- **tg** (token generation, t/s) — how fast the model _writes output_. This dominates interactive chat and **coding**
  (the answer is the long part). 30+ t/s feels fluid (faster than reading speed); under ~15 t/s feels sluggish for
  interactive use but is fine for batch jobs (overnight file organisation, scraping pipelines).
- Rule of thumb per use case: coding = tg-bound with occasional pp spikes (pasting files); document/financial analysis =
  pp-bound (huge inputs, short verdicts); scraping/extraction = pp-bound + wants `--json-schema`; file organisation =
  neither (tiny calls; any model here is instant).

## Benchmark results

Protocol: `llama-bench-<backend> -m <model> -dev {Vulkan0|ROCm0} -fa 1 -r 3` (pp512/tg128 defaults); VRAM sampled from
`/sys/class/drm/card1/device/mem_info_vram_used` during runs. Desktop idle uses ~1.4GiB of the 16.3GiB VRAM.

### 2026-07-03 (post-reboot) — kernel 7.1.0, same userspace (b9608, ROCm 7.2.1, Mesa 26.1.2)

Kernel 6.18.35 → 7.1.0 isolated (same nixpkgs rev): **no change, no regression** — every number within a few percent of
the 6.18 runs below; all verdicts hold. tg-only, r=5 where it mattered:

| Model                                | Backend    | pp512 t/s | tg128 t/s |
| ------------------------------------ | ---------- | --------: | --------: |
| Llama-3.1-8B Q4_K_M                  | **Vulkan** |      2606 | **108.9** |
| Llama-3.1-8B Q4_K_M                  | ROCm       |      2451 |      88.3 |
| Qwen3.6-35B-A3B UD-Q4_K_M, ncmoe=16  | **Vulkan** |       635 |  **50.1** |
| Qwen3.6-35B-A3B UD-Q4_K_M, ncmoe=16  | ROCm       |  **1115** |      43.0 |
| Qwen3.6-35B-A3B UD-Q3_K_XL, ncmoe=12 | Vulkan     |       832 |      53.7 |

(One ROCm MoE run showed tg 51.8±4.8 right after a pp warm-up — boost-clock artifact; disappeared at r=5 with ±0.16.
Don't trust single warm runs.)

### 2026-07-03 — llama.cpp b9608, ROCm 7.2.1, Mesa 26.1.2 RADV, kernel 6.18.35 (nixpkgs = FlakeHub weekly, 26.11-pre)

| Model                                         | Backend    |  pp512 t/s | tg128 t/s | Peak VRAM |
| --------------------------------------------- | ---------- | ---------: | --------: | --------: |
| Llama-3.1-8B-Instruct Q4_K_M (4.6GiB)         | **Vulkan** |       2624 | **108.3** |   ~6.1GiB |
| Llama-3.1-8B-Instruct Q4_K_M                  | ROCm       |       2471 |      88.3 |   ~6.4GiB |
| Qwen3.6-35B-A3B UD-Q4_K_M (20.6GiB), ncmoe=16 | **Vulkan** |        661 |  **51.6** |  ~15.2GiB |
| Qwen3.6-35B-A3B UD-Q4_K_M, ncmoe=20           | Vulkan     |        564 |      45.8 |  ~13.3GiB |
| Qwen3.6-35B-A3B UD-Q4_K_M, ncmoe=16           | ROCm       |   **1089** |      43.0 |  ~15.5GiB |
| Qwen3.6-35B-A3B UD-Q3_K_XL (15.7GiB), ncmoe=8 | Vulkan     | (unstable) |  **57.7** |  ~14.8GiB |
| Qwen3.6-35B-A3B UD-Q3_K_XL, ncmoe=12          | Vulkan     |        975 |      54.0 |  ~14.8GiB |
| Qwen3.6-35B-A3B UD-Q3_K_XL, ncmoe=12          | ROCm       |   **1473** |      49.5 |         — |

Served config (router, `--fit` auto-placement, 32k ctx + q8 KV): Qwen3.6 Q4_K_M measures **tg ~50 / pp ~800 at the API**
(re-verified on the hash-checked file) — i.e. the quality lane writes code at ~2.5× reading speed and ingests a 50-page
document in ~30s; the 8B fast lane stays at ~108 t/s for extraction/file-org calls.

Qwen3.6 hybrid **thinking is disabled server-side** (`reasoning = off` in the preset): with it on, the model burned
2.5k+ hidden tokens (~50s of invisible latency) before answering even trivial prompts. Re-enable per request for deep
analysis with `"chat_template_kwargs": {"enable_thinking": true}` and give it `max_tokens` ≥ 4096.

Qwen3.6-35B-A3B replaced Qwen3-30B-A3B (2026-07-03): +34% tg (51.6 vs 38.6) at higher quality — strictly better. In
practice: Q4_K_M is the served quant (quality); Q3_K_XL trades ~4% quality benchmarks for +10% tg — kept on disk for
experiments.

### 2026-07-03 (earlier, llama.cpp b9190 on the 26.05-chilled nixpkgs) — superseded but kept for trend

| Model                                    | Backend | pp512 t/s | tg128 t/s |
| ---------------------------------------- | ------- | --------: | --------: |
| Llama-3.1-8B Q4_K_M                      | Vulkan  |      3160 |     108.6 |
| Llama-3.1-8B Q4_K_M                      | ROCm    |      3284 |      87.8 |
| Qwen3-30B-A3B MoE Q4_K_M, ncmoe=12       | Vulkan  |       813 |  **38.6** |
| Qwen3-30B-A3B MoE Q4_K_M, ncmoe=12       | ROCm    |  **1326** |      34.2 |
| Ollama 0.30.6 vulkan (API, same 8B GGUF) | —       |     ~1950 |      ~102 |
| Ollama 0.30.6 rocm (API)                 | —       |     ~1640 |    ~65–73 |

**Verdicts** (re-check after every `nix flake update` — see TODO.md):

- **Vulkan** is the serving default: wins tg (what you feel) by ~23% on dense and ~13% on MoE.
- **ROCm stays installed**: it wins MoE _prompt processing_ by ~60% — for a one-off "analyse this huge document with the
  MoE model" job, `llama-server-rocm` is the faster tool.
- **Ollama dropped** (2026-07-03): slower than llama-server on identical weights at both ends; adds a wrapper layer with
  no benefit here.
- **vLLM not installed**: no merged native RDNA4/gfx1201 kernels as of 2026-07-03
  ([vllm-project/vllm#28649](https://github.com/vllm-project/vllm/issues/28649)) — FP8/WMMA paths fall back to slow
  dequant. Re-evaluate when that issue closes.

## llama-server parameter research (b9608, verified against `--help`)

Flags that matter on this hardware, and when to reach for them:

| Flag                                                 | Effect                                                   | Use here                                                                                      |
| ---------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `--n-gpu-layers 99`                                  | everything on GPU                                        | always, for models ≤ ~14GiB                                                                   |
| `--n-cpu-moe N` (`-ncmoe`)                           | first N layers' MoE experts stay in RAM                  | the knob that makes 30B+ MoE fit 16GB; attention stays on GPU so A3B models stay fast         |
| `--fit on` / `--fit-target`                          | auto-tunes unset args (incl. expert offload) to fit VRAM | can replace hand-tuned ncmoe; verify it picks sane values before trusting                     |
| `--flash-attn on`                                    | fused attention                                          | always: +2–4% tg, up to +20% pp measured; required for V-cache quant                          |
| `--cache-type-k/v q8_0`                              | 8-bit KV cache                                           | ~halves KV VRAM ⇒ double the affordable context; the win for document/financial analysis      |
| `--ctx-size`                                         | context window                                           | 16k default; 32–64k + q8 KV for long-document sessions (KV VRAM scales linearly)              |
| `--parallel N`                                       | N server slots                                           | 2–4 for scraping pipelines (slots share the ctx budget)                                       |
| `--json-schema` / grammars                           | constrained JSON output                                  | per-request from the API; makes extraction/file-org outputs machine-parseable, no retries     |
| `--threads 8` / `--threads-batch 16`                 | CPU threads tg / pp                                      | 8 physical cores for generation (SMT hurts), 16 for prefill; only matters with experts in RAM |
| `--mlock`                                            | pin weights in RAM                                       | with 62GB, stops offloaded experts being paged out                                            |
| `--spec-type ngram-*`                                | draft-free speculative decoding                          | free tg boost on repetitive output (code edits); untested here — candidate experiment         |
| `--spec-type draft-mtp`                              | MTP speculative decoding                                 | needs the Qwen3.6 **MTP** GGUF; potentially large tg gain — TODO item 2                       |
| `--jinja`, `--reasoning auto`                        | templates + thinking-tag handling                        | always on the server                                                                          |
| Router mode: `--models-preset INI`, `--models-max 1` | one endpoint, many models, load-on-demand                | the serving shape used here; VRAM bounded to one loaded model                                 |

## Model research for the use cases (mid-2026, 16GB VRAM + 62GB RAM)

| Use case                      | Pick                                                   | Why                                                                                                       |
| ----------------------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| Coding (interactive/agentic)  | **Qwen3.6-35B-A3B**                                    | current 16GB-class sweet spot; agentic-coding tuned; 3B active tolerates expert offload                   |
| Coding (max quality, slower)  | Qwen3-Coder-Next 80B-A3B                               | ~46GB at 4-bit ⇒ most experts in RAM; est. 15–20 t/s; download-on-demand option                           |
| Document/financial analysis   | **gpt-oss-20b** (candidate, not yet installed)         | native MXFP4 fits _entirely_ in VRAM (~13GiB) ⇒ no offload penalty; strong reasoning; consensus 16GB pick |
| Scraping/extraction, file org | Llama-3.1-8B (installed) + `--json-schema`             | 108 t/s; quality is ample for structured extraction; Qwen3-8B a marginal swap-in upgrade                  |
| RAG embeddings (optional)     | Qwen3-Embedding-0.6B via a second `--embedding` server | ~1GiB VRAM                                                                                                |

Skipped: Gemma 4 26B MoE and Qwen3.6-27B dense — both land at 16–18GiB at Q4, over the ceiling, and dense models degrade
badly when partially offloaded (MoE degrades gracefully).

**Llama 4 Scout — evaluated 2026-07-03, not worth measuring here.** Not new (April 2025); 109B total / **17B active**
MoE. Q4 is ~54.5GiB (doesn't fit 16GB VRAM at any respectable quant; the 1.78-bit 32GiB build targets 24GB cards). The
killer is the 17B _active_ parameters: with experts offloaded to RAM, every token streams ~10GiB+ from system memory →
single-digit t/s here, versus Qwen3.6-35B-A3B's 3B active at ~50 t/s. Benchmark quality is also generally behind
Qwen3.6-class models. Revisit only if a much smaller Llama 4.x MoE (≤5B active) appears.

2026-07 landscape re-check (post kernel-7.1 bench) — additional candidates if wanted, in order of fit:

- **Mistral Small 3.1 24B** (dense, ~13GiB Q4_K_M): strongest dense generalist that fully fits; est. tg ~35–40 here by
  bandwidth math. Alternative to gpt-oss-20b if its reasoning-channel output style is unwanted.
- **Apriel 1.5 15B-Thinker** (~10GiB): vision + reasoning — screenshot/scanned-page analysis; pairs with document
  workflows if image input matters.
- Qwen3-14B / DeepSeek-R1-14B distills: superseded for this box by Qwen3.6-35B-A3B (similar speed, lower quality).

Sources: [Qwen3.6-35B-A3B blog](https://qwen.ai/blog?id=qwen3.6-35b-a3b),
[unsloth Qwen3.6 guide](https://unsloth.ai/docs/models/qwen3.6),
[Qwen3-Coder-Next guide](https://unsloth.ai/docs/models/qwen3-coder-next),
[LocalLLM 16GB tests](https://localllm.in/blog/best-local-llms-16gb-vram),
[VRAM-tier guide](https://www.promptquorum.com/local-llms),
[16GB use-case guide](https://www.mayhemcode.com/2026/05/best-models-to-run-on-12gb-and-16gb.html),
[unsloth Llama 4 guide](https://unsloth.ai/docs/models/tutorials/llama-4-how-to-run-and-fine-tune),
[Llama 4 Scout specs/VRAM](https://apxml.com/models/llama-4-scout),
[16GB tested+ranked 2026](https://quantized.fyi/models/best-llm-models-for-16gb-vram-in-2026-tested-and-ranked/),
[16GB selection guide](https://localvram.com/en/blog/16gb-vram-model-selection-guide/).

## Recipes

- **Downloading models — ALWAYS verify the hash.** A corrupted GGUF still _benchmarks_ normally (throughput doesn't
  depend on weight values) but generates garbage; the failure mode is silent until you read output. Compare
  `sha256sum <file>` against HF's LFS oid:
  `curl -s 'https://huggingface.co/api/models/<org>/<repo>/tree/main' | jq -r '.[] | select(.path=="<file>") | .lfs.oid'`.
  Never run two `curl -C -` resumes against the same file (2026-07-03 lesson: an interrupted download's curl survived a
  network drop and overlapped with its replacement — both appended, file grew past the true size, model spoke only
  `/////`).

- **Re-bench after an update**: `llama-bench-vulkan -m /var/lib/llm/models/<m>.gguf -dev Vulkan0 -fa 1 -r 3` (and
  `-rocm`/`ROCm0`); update the table above and flip `services.llama-cpp.package` in `llm.nix` if the verdict changes.
- **Add a model to the router**: drop the GGUF in `/var/lib/llm/models`, add a section to the preset in `llm.nix`,
  rebuild. Clients select it via the `model` field; `--models-max 1` swaps on demand.
- **Free the VRAM** (e.g. before gaming): `systemctl restart llama-cpp` (unloads models until next request) or
  `systemctl stop llama-cpp`.
