# Local LLM Runtimes & Model Selection Guide

This guide covers the two primary runtimes that work with LocalLLMChat — Ollama and LM Studio — and gives practical hardware-based guidance on which models to run.

---

## Table of Contents

- [Understanding quantization](#understanding-quantization)
- [Hardware tiers](#hardware-tiers)
- [Ollama](#ollama)
- [LM Studio](#lm-studio)
- [Model recommendations by hardware tier](#model-recommendations-by-hardware-tier)
- [Model recommendations by use case](#model-recommendations-by-use-case)
- [Notable models at a glance](#notable-models-at-a-glance)
- [Tips for better performance](#tips-for-better-performance)

---

## Understanding quantization

Model files are distributed in various quantization formats that trade accuracy for file size and memory use. The format appears in the model name as a suffix (e.g. `llama3.1:8b-instruct-q4_K_M`).

| Format | Bits per weight | Quality loss | Notes |
|--------|----------------|--------------|-------|
| `F16` / `fp16` | 16 | None | Full precision; largest files; needs most VRAM |
| `Q8_0` | 8 | Negligible | Near-lossless; good if you have the VRAM |
| `Q6_K` | 6 | Very low | Excellent balance; recommended for 24 GB+ GPUs |
| `Q5_K_M` | 5 | Low | Good quality; practical for 12–16 GB VRAM |
| `Q4_K_M` | 4 | Moderate | **Most popular default**; fits on 8 GB VRAM for 7B models |
| `Q4_0` | 4 | Moderate | Slightly lower quality than Q4_K_M; faster on some hardware |
| `Q3_K_M` | 3 | Noticeable | Use only when VRAM is very limited |
| `Q2_K` | 2 | High | Last resort; quality degrades significantly |

### Quick sizing formula

A rough estimate of VRAM or RAM needed to load a model:

```
Memory (GB) ≈ (parameter count in billions) × (bits per weight / 8) × 1.1
```

Examples:
- 7B model at Q4_K_M: 7 × 0.5 × 1.1 ≈ **~4 GB**
- 7B model at F16:    7 × 2.0 × 1.1 ≈ **~15 GB**
- 13B model at Q4_K_M: 13 × 0.5 × 1.1 ≈ **~7 GB**
- 70B model at Q4_K_M: 70 × 0.5 × 1.1 ≈ **~39 GB**

Add ~1–2 GB on top for the runtime overhead and KV cache.

### GPU vs CPU inference

- **GPU inference** (VRAM): fast — typically 30–100+ tokens/sec on a mid-range GPU
- **CPU inference** (RAM): slow — typically 3–15 tokens/sec depending on CPU and model size
- **Hybrid** (model split across GPU VRAM + system RAM): possible with Ollama and LM Studio; slower than full-GPU but faster than full-CPU

If the model fits entirely in VRAM, responses feel near-instant. If it spills into RAM, expect a noticeable slowdown.

---

## Hardware tiers

Use this table to quickly find your tier before looking at model recommendations below.

| Tier | Example hardware | VRAM / RAM | What fits |
|------|-----------------|-----------|-----------|
| **CPU only** | Any modern CPU, 8 GB RAM | 0 GB VRAM | Up to 3B Q4; 7B is sluggish |
| **CPU only (capable)** | 16–32 GB RAM | 0 GB VRAM | 7B Q4 usable; 13B slow |
| **Entry GPU** | RTX 3060 / RX 6600 (8 GB) | 8 GB | 7B Q4_K_M comfortably; 13B tight |
| **Mid-range GPU** | RTX 3080 / 4070 (12 GB) | 12 GB | 13B Q4_K_M; 7B Q8 |
| **High-end GPU** | RTX 3090 / 4090 (24 GB) | 24 GB | 34B Q4_K_M; 13B Q8; 7B F16 |
| **Workstation / server** | A6000 / A100 (48–80 GB) | 48–80 GB | 70B Q4; 34B Q8; 13B F16 |
| **Multi-GPU** | 2× 4090 (48 GB combined) | 48 GB | 70B Q4; 34B Q8 |
| **Apple Silicon** | M2/M3/M4 Mac (unified memory) | 16–192 GB | Depends on chip; M3 Max 64 GB runs 70B Q4 |

> **Apple Silicon note**: Ollama uses Apple's Metal GPU acceleration automatically. Because memory is unified (shared CPU/GPU), the full RAM figure applies. An M3 MacBook Pro with 36 GB can run 34B models at Q4 comfortably.

---

## Ollama

### What it is

[Ollama](https://ollama.com) is a lightweight, open-source daemon that downloads, manages, and serves local LLM models over a simple HTTP API. It handles GGUF model files, GPU detection, Metal/CUDA/ROCm acceleration, and context management automatically.

### How it works

1. `ollama serve` starts a background daemon on `http://localhost:11434`
2. `ollama pull <model>` downloads a model from the Ollama registry (GGUF format)
3. Models are stored in `~/.ollama/models/` (Linux/macOS) or `%USERPROFILE%\.ollama\models` (Windows)
4. The daemon exposes a REST API: `/api/chat`, `/api/generate`, `/api/tags`, etc.
5. LocalLLMChat sends requests to `/api/chat` and receives JSON responses

### Installation

```bash
# Linux / macOS (recommended)
curl -fsSL https://ollama.com/install.sh | sh

# macOS via Homebrew
brew install ollama

# Windows
# Download OllamaSetup.exe from https://ollama.com/download
```

### Key commands

```bash
# Pull a model (downloads if not present)
ollama pull llama3.2

# Pull a specific variant
ollama pull llama3.1:8b-instruct-q5_K_M

# List downloaded models
ollama list

# Run a model interactively (CLI chat)
ollama run llama3.2

# Remove a model
ollama rm llama3.2

# Show model details (parameters, template, license)
ollama show llama3.2

# Check what's running / loaded in memory
ollama ps

# Update all models to latest versions
ollama-update-models               # if installed via install-service-linux.sh
./update-models.sh                 # from source directory
```

### Configuration via environment variables

Set these before starting `ollama serve`, or in the systemd service override.

| Variable | Default | Purpose |
|----------|---------|---------|
| `OLLAMA_HOST` | `127.0.0.1:11434` | Bind address — set to `0.0.0.0:11434` for network access |
| `OLLAMA_MODELS` | `~/.ollama/models` | Where model files are stored |
| `OLLAMA_NUM_PARALLEL` | `1` | Concurrent request slots |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Models kept in memory simultaneously |
| `OLLAMA_GPU_OVERHEAD` | `0` | Reserve this many bytes of VRAM for the OS |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long to keep a model loaded after last use |
| `CUDA_VISIBLE_DEVICES` | all | Which GPU(s) to use (e.g. `0`, `0,1`) |

#### Example: expose Ollama on the network

```bash
# Linux systemd override
sudo systemctl edit ollama
# Add:
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

```bash
# macOS launchd / brew services
launchctl setenv OLLAMA_HOST "0.0.0.0:11434"
brew services restart ollama
```

### Modelfile customisation

You can create a custom model with a different system prompt or parameters:

```dockerfile
# Modelfile
FROM llama3.2

SYSTEM """
You are a concise technical assistant. Answer in bullet points.
"""

PARAMETER temperature 0.3
PARAMETER num_ctx 8192
```

```bash
ollama create my-assistant -f Modelfile
ollama run my-assistant
```

### Context window

Ollama defaults to a 2048-token context window for most models. Many models support much larger contexts (8K, 32K, 128K). To increase it, set `num_ctx` in a Modelfile or pass it in the API request:

```json
{ "options": { "num_ctx": 16384 } }
```

Larger contexts use proportionally more VRAM (for the KV cache). A 7B model at 4K context needs ~5 GB VRAM; at 32K context it needs ~10+ GB.

---

## LM Studio

### What it is

[LM Studio](https://lmstudio.ai) is a cross-platform GUI application for downloading, browsing, and running local LLMs. It provides a chat interface, a model browser connected to Hugging Face, and a local OpenAI-compatible server. It supports GGUF models and handles GPU offloading automatically.

### How it works

1. Download and run the LM Studio desktop app
2. Use the built-in model browser to search and download GGUF models from Hugging Face
3. Load a model into memory from the "My Models" tab
4. Start the local server from the "Local Server" tab (default port: 1234)
5. LocalLLMChat sends requests to `/v1/chat/completions` using the OpenAI format

### Installation

| Platform | Method |
|----------|--------|
| Windows | Download the `.exe` installer from lmstudio.ai |
| macOS | Download the `.dmg` from lmstudio.ai; Apple Silicon and Intel builds available |
| Linux | Download the `.AppImage` from lmstudio.ai |

### Connecting to LocalLLMChat

1. Open LM Studio → load a model → start the local server
2. In LocalLLMChat, set **Endpoint** to `http://localhost:1234`
3. Set **Model** to the model identifier shown in LM Studio (e.g. `lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF`)
4. Or leave **Model** blank — LM Studio will use whichever model is loaded

### LM Studio vs Ollama

| | Ollama | LM Studio |
|---|--------|-----------|
| Interface | CLI daemon + API | GUI app + API |
| Model source | Ollama registry | Hugging Face (any GGUF) |
| GPU acceleration | Auto (CUDA/Metal/ROCm) | Auto (configurable layers) |
| API format | Ollama native + OpenAI-compat | OpenAI-compatible |
| Headless / server use | Excellent | GUI required to load models |
| Model customisation | Modelfiles | In-app settings |
| Best for | Servers, automation, scripts | Desktop exploration, trying models |

### GPU layer offloading in LM Studio

LM Studio lets you set how many model layers to offload to the GPU. More layers = faster inference but more VRAM used. Setting it to the maximum your GPU can hold is the optimal approach. LM Studio shows estimated VRAM usage as you drag the slider.

---

## Model recommendations by hardware tier

### CPU only — 8 GB RAM

Inference will be slow (3–8 tok/s). Keep models small.

| Model | Size | Notes |
|-------|------|-------|
| `llama3.2:1b` | ~0.8 GB | Fastest; good for quick tasks |
| `llama3.2:3b` | ~2 GB | Better quality; still responsive |
| `phi3:mini` (`phi3:3.8b`) | ~2.3 GB | Punches above its weight for reasoning |
| `gemma2:2b` | ~1.6 GB | Google's efficient small model |
| `tinyllama` | ~0.6 GB | Testing only; limited capability |

### CPU only — 16–32 GB RAM

More breathing room; 7B models are usable, if slow.

| Model | Size | Notes |
|-------|------|-------|
| `llama3.2:3b` | ~2 GB | Fast and capable |
| `mistral:7b-instruct-q4_0` | ~4 GB | Solid general purpose |
| `llama3.1:8b-q4_K_M` | ~5 GB | Strong instruction-following |
| `phi3:medium` (14B) | ~8 GB | Excellent for reasoning tasks |

### Entry GPU — 6–8 GB VRAM (e.g. RTX 3060, RX 6600)

7B models fit comfortably at Q4; some 13B models fit with reduced context.

| Model | VRAM needed | Notes |
|-------|------------|-------|
| `llama3.2:3b` | ~2 GB | Near-instant responses |
| `mistral:7b-instruct-q4_K_M` | ~4.5 GB | Fast; good general assistant |
| `llama3.1:8b-q4_K_M` | ~5 GB | Strong instruction-following |
| `codellama:7b-q4_K_M` | ~4.5 GB | Code generation |
| `gemma2:9b-q4_K_M` | ~6 GB | Google's capable 9B model; fits 8 GB |
| `phi3:medium-q4` (14B) | ~8 GB | May require reducing context window |

### Mid-range GPU — 12–16 GB VRAM (e.g. RTX 3080, 4070, 4070 Ti)

13B models run well; 34B models may work at lower quantization.

| Model | VRAM needed | Notes |
|-------|------------|-------|
| `llama3.1:8b-q8_0` | ~9 GB | High-quality 8B at near-lossless quant |
| `mistral:7b-instruct-q8_0` | ~8 GB | High-quality Mistral |
| `llama3.1:8b-q4_K_M` | ~5 GB | Leaves headroom for larger context |
| `codellama:13b-q4_K_M` | ~8 GB | Better code generation than 7B |
| `llama3.1:70b-q2_K` | ~30 GB | Too large — use 34B instead |
| `phi3:medium-14b-q5_K_M` | ~10 GB | Strong reasoning and maths |
| `deepseek-coder:6.7b-instruct` | ~4.5 GB | Excellent for coding tasks |
| `qwen2.5:14b-q4_K_M` | ~9 GB | Multilingual; strong at reasoning |

### High-end GPU — 24 GB VRAM (e.g. RTX 3090, 4090, A5000)

34B models run well; 70B models require Q3 or lower.

| Model | VRAM needed | Notes |
|-------|------------|-------|
| `llama3.1:8b` (F16) | ~16 GB | Full precision 8B |
| `llama3.3:70b-q2_K` | ~26 GB | 70B at very low quant — just fits |
| `codellama:34b-q4_K_M` | ~20 GB | Best code model that fits on 24 GB |
| `mixtral:8x7b-instruct-q4_K_M` | ~26 GB | MoE model; very capable; tight fit |
| `qwen2.5:32b-q4_K_M` | ~20 GB | Strong at reasoning and multilingual |
| `phi3:medium-14b-q8_0` | ~16 GB | Near-lossless 14B |
| `deepseek-coder:33b-q4_K_M` | ~20 GB | State-of-the-art coding |

### Workstation / server — 48+ GB VRAM or Apple Silicon 64+ GB

70B models run comfortably at Q4 or higher.

| Model | VRAM needed | Notes |
|-------|------------|-------|
| `llama3.1:70b-q4_K_M` | ~40 GB | Flagship open-source model |
| `llama3.3:70b-q5_K_M` | ~50 GB | Very high quality 70B |
| `qwen2.5:72b-q4_K_M` | ~42 GB | Multilingual powerhouse |
| `deepseek-r1:70b` | ~40 GB | Reasoning-focused 70B |
| `mixtral:8x22b-q3_K_M` | ~50 GB | MoE 8×22B — enormous capability |
| `codellama:70b-q4_K_M` | ~40 GB | Best open-source code model |

---

## Model recommendations by use case

### General conversation and Q&A

| Tier | Recommended | Alternative |
|------|------------|-------------|
| Low-end | `llama3.2:3b` | `gemma2:2b` |
| Mid-range | `llama3.1:8b-q4_K_M` | `mistral:7b-instruct` |
| High-end | `llama3.3:70b-q4_K_M` | `qwen2.5:32b` |

### Coding and software development

| Tier | Recommended | Alternative |
|------|------------|-------------|
| Low-end | `phi3:mini` | `codellama:7b` |
| Mid-range | `deepseek-coder:6.7b-instruct` | `codellama:13b` |
| High-end | `deepseek-coder:33b` | `codellama:34b` |

### Creative writing and storytelling

Models with higher temperature settings (0.8–1.2) work best. Avoid heavily instruction-tuned models if you want creative freedom.

| Tier | Recommended | Notes |
|------|------------|-------|
| Low-end | `llama3.2:3b` | Set temp to 1.0+ |
| Mid-range | `mistral:7b-instruct` | Flexible and imaginative |
| High-end | `llama3.1:70b` | Best narrative coherence |

### Summarisation and document analysis

Long-context models matter here. Check `num_ctx` support.

| Model | Context | Notes |
|-------|---------|-------|
| `llama3.1:8b` | 128K | Excellent long-doc support |
| `mistral:7b` | 32K | Good for most documents |
| `qwen2.5:14b` | 128K | Strong at analysis |
| `gemma2:9b` | 8K | Shorter context limit |

### Multilingual (non-English)

| Model | Strong languages | Notes |
|-------|----------------|-------|
| `qwen2.5:7b` | Chinese, Japanese, Korean, Arabic, French, German, Spanish | Best multilingual in its class |
| `mistral:7b` | French, Spanish, Italian, German | Good European language support |
| `llama3.1:8b` | Spanish, French, German, Portuguese, Hindi | Meta's multilingual training |
| `aya:8b` | 23+ languages | Cohere's multilingual-first model |

### Maths and reasoning

| Model | Notes |
|-------|-------|
| `phi3:medium` (14B) | Microsoft's reasoning-focused model; outperforms many larger models |
| `deepseek-r1:7b` | Chain-of-thought reasoning; strong on benchmarks |
| `qwen2.5:7b` | Strong maths; quantitative reasoning |
| `llama3.1:70b` | Best general reasoning at high resource levels |

---

## Notable models at a glance

| Model family | Creator | Strengths | Ollama name |
|-------------|---------|-----------|-------------|
| **Llama 3.1 / 3.2 / 3.3** | Meta | General purpose, strong instruction-following, large ecosystem | `llama3.2`, `llama3.1:8b`, `llama3.3:70b` |
| **Mistral / Mixtral** | Mistral AI | Fast, efficient, good European language support; MoE variant very capable | `mistral`, `mixtral` |
| **Phi-3 / Phi-4** | Microsoft | Exceptional reasoning per parameter; small but punches above weight | `phi3:mini`, `phi3:medium` |
| **Gemma 2** | Google | Clean and coherent output; 2B and 9B are efficient | `gemma2:2b`, `gemma2:9b` |
| **Qwen 2.5** | Alibaba | Best-in-class multilingual; strong maths and coding | `qwen2.5:7b`, `qwen2.5:14b` |
| **DeepSeek Coder** | DeepSeek | State-of-the-art code generation | `deepseek-coder:6.7b-instruct` |
| **DeepSeek R1** | DeepSeek | Chain-of-thought reasoning; distilled variants available | `deepseek-r1:7b` |
| **CodeLlama** | Meta | Code generation and completion, based on Llama 2 | `codellama:7b`, `codellama:34b` |
| **Aya** | Cohere | 23-language multilingual model | `aya:8b` |

Browse the full Ollama model library at: **https://ollama.com/library**

---

## Tips for better performance

### Match quantization to your hardware

- If the model fits in VRAM at Q5_K_M, use Q5_K_M over Q4_K_M — the quality difference is meaningful
- Only drop to Q3 or Q2 when you have no other option
- Q8_0 is worth it for 7B models on 12+ GB VRAM cards — noticeably better output quality

### Context window vs VRAM

The KV cache for long contexts consumes significant VRAM:

```
KV cache VRAM (GB) ≈ (num_ctx / 1024) × (num_layers / 32) × 0.25
```

If you're getting out-of-memory errors but the model should fit, reduce `num_ctx` first.

### Keep only one model loaded

By default Ollama unloads a model after 5 minutes of inactivity. If you switch between models frequently, the reload time (typically 5–15 seconds) can be annoying. Set `OLLAMA_KEEP_ALIVE=1h` to keep models loaded longer. Conversely, if you run low on VRAM, set `OLLAMA_KEEP_ALIVE=0` to unload immediately after each response.

### CPU inference: use fewer threads than cores

Ollama defaults to using all logical CPU cores. On hyperthreaded CPUs, performance is often better with physical core count only:

```bash
# Example for a 6-core / 12-thread CPU
OLLAMA_NUM_THREAD=6 ollama serve
```

### Temperature guide

| Task | Temperature | Effect |
|------|------------|--------|
| Factual Q&A, code | 0.1–0.4 | Precise, deterministic |
| General chat | 0.6–0.8 | Balanced |
| Creative writing | 0.9–1.2 | More varied and imaginative |
| Brainstorming | 1.2–1.5 | High variance — expect surprising results |

### Monitor GPU usage

```bash
# NVIDIA
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv -l 2

# AMD
watch -n 2 rocm-smi --showmemuse

# macOS (Apple Silicon)
sudo powermetrics --samplers gpu_power -i 1000
```
