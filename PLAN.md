# LauronFlow — local Wispr Flow-style dictation for macOS

## Context

Personal, fully-offline voice dictation app for a MacBook Air (Apple Silicon, 16GB RAM,
macOS 26.5). Hold a global hotkey anywhere on macOS, speak, release — the transcript is
typed into whatever app has focus. No cloud calls, no telemetry.

Confirmed decisions (not up for re-litigation during implementation):
- STT engine: NVIDIA Parakeet TDT v3 (`mlx-community/parakeet-tdt-0.6b-v3`) via the
  `parakeet-mlx` Python package (Apple MLX, Apple Silicon only).
- No LLM cleanup pass — raw Parakeet output (already punctuated/cased) is typed as-is.
- Native Swift/SwiftUI menu bar app for hotkey + recording + text injection + UI.
- Since Parakeet has no mature Swift/MLX-Swift port, the Swift app talks to a bundled
  local Python sidecar process over a Unix domain socket.
- Personal use only — a stable local self-signed code-signing certificate is used (so TCC
  permission grants survive rebuilds), no paid Apple Developer account, App Sandbox
  disabled (needed to spawn the sidecar subprocess and post synthetic CGEvents).

## Project layout

```
LauronFlow/
├── LauronFlow.xcodeproj/              # Xcode app target (not raw SwiftPM exe — see rationale below)
├── LauronFlow/
│   ├── LauronFlowApp.swift            # @main, no WindowGroup (menu bar only)
│   ├── AppDelegate.swift              # wires hotkey + recorder + sidecar client + text injector
│   ├── Info.plist                     # LSUIElement=YES, NSMicrophoneUsageDescription
│   ├── LauronFlow.entitlements        # App Sandbox = NO
│   ├── StatusBar/
│   │   ├── StatusItemController.swift # NSStatusItem, menu, icon per AppState
│   │   └── AppState.swift             # idle / recording / transcribing / error
│   ├── Hotkey/
│   │   └── HotkeyManager.swift        # NSEvent global monitor (flagsChanged), push-to-talk
│   ├── Audio/
│   │   ├── AudioRecorder.swift        # AVAudioEngine -> 16kHz mono WAV temp file
│   │   └── AudioConstants.swift
│   ├── Sidecar/
│   │   ├── SidecarProcessManager.swift# launches/supervises python sidecar, restart on crash
│   │   ├── SidecarClient.swift        # Unix domain socket client (BSD sockets)
│   │   └── SidecarPaths.swift         # shared socket/log/tmp path constants
│   ├── TextInjection/
│   │   └── TextInjector.swift         # pasteboard swap + synthetic Cmd+V via CGEvent
│   ├── Permissions/
│   │   └── PermissionsHelper.swift    # AXIsProcessTrustedWithOptions, mic permission
│   └── Startup/
│       └── LaunchAtLoginManager.swift # SMAppService wrapper
└── sidecar/                           # independent uv-managed Python project
    ├── pyproject.toml                 # dep: parakeet-mlx  (ffmpeg via brew, not pip)
    └── src/lauronflow_sidecar/
        ├── __main__.py                # loads model once, starts server
        ├── model.py                   # from_pretrained("mlx-community/parakeet-tdt-0.6b-v3")
        ├── server.py                  # UnixStreamServer, newline-delimited JSON protocol
        └── protocol.py
```

**Why Xcode app target, not SwiftPM executable:** menu bar apps need a reliable Info.plist
and a real `.app` bundle — TCC permission prompts (Accessibility, Microphone) key off the
bundle identifier/code signature of an actual `.app`. Xcode gives this for free.

## Sidecar protocol

- Socket: `~/Library/Application Support/LauronFlow/sidecar.sock` (path passed to the
  Python process via env var so Swift owns the single source of truth).
- Model loaded once at process startup (multi-second load — must not repeat per utterance).
- Per utterance: Swift opens a new connection, writes `<absolute WAV path>\n`, sidecar
  responds with one line of JSON: `{"status":"ok","text":"..."}\n` or
  `{"status":"error","message":"..."}\n`, then closes the connection.
- Swift owns temp WAV lifecycle (create before send, delete after response).
- Readiness: sidecar creates the socket file only after the model is loaded and the
  server is listening, so "file exists" ≈ "ready"; Swift polls for it (~60s timeout).

## Swift app design

- **Hotkey:** default = hold **Right Option (⌥)**, detected via
  `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` — observes without
  swallowing the keystroke, needs Accessibility permission, no CGEventTap required.
- **Recording:** `AVAudioEngine` tap → `AVAudioConverter` down to 16kHz mono 16-bit PCM WAV
  in a temp file while the hotkey is held.
- **Sidecar client:** raw BSD sockets (`import Darwin`) for connect/send/recv, run off the
  main thread; `SO_RCVTIMEO` so a hung sidecar can't hang the UI.
- **Text injection:** save current pasteboard → set transcript as string → synthesize
  Cmd+V via `CGEvent` → restore original pasteboard ~300ms later.
- **Permissions:** `NSMicrophoneUsageDescription` in Info.plist; Accessibility trust
  requested via `AXIsProcessTrustedWithOptions` (covers both hotkey monitoring and
  synthetic paste — one prompt for both).
- **Sandbox:** disabled — required to spawn the sidecar subprocess and post CGEvents to
  other apps.

## Setup prerequisites

- Xcode (latest stable for macOS 26.5 SDK)
- `brew install uv` (Python project/venv runner)
- `brew install ffmpeg` (required by parakeet-mlx for audio decoding)
- Swift app resolves `uv`'s path explicitly (Finder-launched apps don't inherit shell
  PATH) — check `/opt/homebrew/bin/uv`, `/usr/local/bin/uv`, `~/.local/bin/uv`, etc.
- **Gotcha:** `uv`'s editable installs set the macOS `UF_HIDDEN` flag on the generated
  `.pth`/`dist-info` in `.venv`, and this Python 3.11 build's `site.py` silently skips
  hidden `.pth` files — so `lauronflow_sidecar` fails to import unless installed
  non-editable. `SidecarProcessManager` MUST set `UV_NO_EDITABLE=1` in the environment
  it passes to the `uv run` subprocess (confirmed working in M1/M2 testing).
- **Gotcha:** ad-hoc "Sign to Run Locally" signing (`CODE_SIGN_IDENTITY: "-"`) hashes the
  binary itself, so every rebuild produces a new signing identity and macOS resets all TCC
  grants (Accessibility, Microphone) for the app — extremely disruptive during active
  development. Fixed by signing with a persistent local self-signed "Code Signing"
  certificate (created once via Keychain Access' Certificate Assistant) instead, which
  keeps the same identity across rebuilds.

## Milestones (each independently testable)

1. **M1 — Sidecar standalone:** `uv sync` in `sidecar/`, load the model, transcribe a
   sample WAV via a throwaway script. Confirms model download, MLX, ffmpeg all work.
2. **M2 — Persistent socket server:** wrap M1 in `server.py`, start it, hit it twice in
   the same run via a test client script — proves the model loads once and is reused.
3. **M3 — Swift skeleton:** menu bar icon appears (no dock icon), app auto-launches the
   sidecar subprocess, mic permission prompt fires, a manual "Test Transcription" menu
   item records ~3s and round-trips through the sidecar, transcript logged to console.
4. **M4 — Real hotkey:** Right-Option hold/release drives record → transcribe, icon
   reflects state, Accessibility permission prompt verified (including revoke → detect).
5. **M5 — Text injection:** dictated text lands in TextEdit, Notes, a browser address bar,
   and a terminal prompt; clipboard is restored afterward (verified by pasting).
6. **M6 — Polish:** icon states for all phases, mic/Accessibility-denied error states,
   sidecar crash auto-restart with retry cap, silence/empty-transcript handling, sidecar
   launched proactively at app startup (not lazily), optional "Launch at Login" via
   `SMAppService`.

All six milestones above are done and verified live on-device.

## Verification

Each milestone above doubles as its own test — run it manually on the machine (no
automated UI test harness needed for a personal single-user app). Final end-to-end check:
hold hotkey with focus in a real app, speak a full sentence, release, confirm accurate
text appears and original clipboard is restored.
