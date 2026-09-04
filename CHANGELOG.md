# Changelog

All notable changes to LauronFlow are documented here. The sidecar lives in a separate
repository (`lauronflow-sidecar`); sidecar-affecting changes are flagged below so both
repos get tagged together at release time.

## [1.0.3] — 2026-09-04

### Memory & performance overhaul

Sidecar memory dropped ~60% and per-dictation latency dropped ~60% with no measurable
accuracy change (verified on the standard sample utterance — 8-bit output was
byte-identical to the previous bf16 model).

Measurements (live, MacBook Air 16 GB):

| Metric | Before | After |
| --- | --- | --- |
| Sidecar physical footprint | 2.6 GB (2.5 GB swapped) | 1.0 GB (peak 1.2 GB, no sidecar swap) |
| Model weights on disk | 2.3 GB fp32 | 0.9 GB 8-bit |
| Transcription (sample.wav) | ~1.2 s | 0.41 s first, 0.13 s warm |
| Transcript accuracy | — | identical output |

Changes:

- **Sidecar: switch to an 8-bit quantized model**
  `mlx-community/parakeet-tdt-0.6b-v3` → `animaslabs/parakeet-tdt-0.6b-v3-mlx-8bit`
  (loads via `nn.quantize()` + `load_weights`). First-launch download shrinks from
  ~2.3 GB to ~0.9 GB.
- **Sidecar: bound MLX memory** — `mx.set_memory_limit` (4 GB) / `mx.set_cache_limit`
  (1 GB) safety caps, plus `mx.clear_cache()` after every transcription so a long-lived
  server can't accumulate activation caches between dictations.
- **Sidecar: skip ffmpeg per utterance** — the recorder's 16 kHz mono PCM16 WAVs are
  decoded directly with `wave` + `numpy`; ffmpeg is now only a fallback for non-WAV
  input (still required to be on PATH, but no longer spawned per dictation).
- **App: `SidecarProcessManager` skips `uv sync` on launch** when the sidecar source is
  unchanged (SHA-256 of `src/*.py`, `pyproject.toml`, `uv.lock` vs. a stored hash),
  cutting seconds off every app launch. Re-syncs automatically when sidecar code
  changes and on first run after this update.
- **App: `sidecar.log` rotates at 2 MB** instead of growing without bound.
- **App: `AudioRecorder` buffer reuse + vDSP RMS** — one reusable conversion buffer per
  recording instead of a fresh allocation per audio callback (~12x/s), and RMS level
  math via `vDSP_measqv` instead of a Swift loop. Level updates are skipped when
  nothing is listening.
- **App: `VocabularyStore` caches compiled regexes** — patterns compile once on first
  use (or when edited) instead of on every dictation.

### Docs

- README, PLAN.md, and sidecar README updated for the quantized model, new download
  size, and the ffmpeg-fallback behavior of the sidecar.

### Release tags

- Main repo: `v1.0.3` (app marketing version 1.0.3, build 4)
- Sidecar repo: `v0.2.0`