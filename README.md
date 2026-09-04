# LauronFlow

<p align="center">
  <img src="logo.png" width="140" alt="LauronFlow logo" />
</p>

A local, fully-offline voice dictation app for macOS (Apple Silicon). Hold a global
hotkey anywhere, speak, release — the transcript is typed into whatever app has focus.
No cloud calls, no telemetry, no account.

Speech-to-text runs on-device via [Parakeet TDT](https://huggingface.co/animaslabs/parakeet-tdt-0.6b-v3-mlx-8bit)
(NVIDIA, via Apple's MLX, 8-bit quantized), spawned as a local Python sidecar process
the Swift menu bar app talks to over a Unix socket.

**Requirements:** Apple Silicon Mac, macOS 14+.

This is a personal project shared for testing among friends — it isn't notarized or
distributed through the App Store, so there's a bit of one-time setup either way below.
Every install starts a **14-day free trial**; after that, dictation is disabled until a
license is activated (Settings → License). The license key is the only thing this app
ever sends over the network — audio and transcripts never leave your Mac.

## Option A: Download the prebuilt release (easiest)

The release `.app` is self-contained — the speech-to-text sidecar is bundled inside it,
so there's no separate repo to clone.

1. Grab the latest `LauronFlow.app.zip` from [Releases](../../releases), unzip it, and
   drag `LauronFlow.app` into `/Applications`.
2. It's signed with a personal self-signed certificate, not an Apple Developer ID, so
   Gatekeeper will refuse to open it normally. Bypass that once with:
   ```
   xattr -cr /Applications/LauronFlow.app
   ```
   (or right-click the app → Open → Open, on the "unidentified developer" prompt).
3. Install the two runtime dependencies the sidecar needs:
   ```
   brew install uv ffmpeg
   ```
4. Launch LauronFlow from `/Applications`. A one-time onboarding window appears first,
   walking through the hotkey, undo, and the permission prompts you're about to see —
   click "Get Started" to continue.
5. Grant permissions when prompted: **Microphone** and **Accessibility** (System
   Settings → Privacy & Security). Accessibility is required for typing the transcript
   into other apps — without it LauronFlow can transcribe but can't inject text.
6. First launch downloads the ~900MB Parakeet model (8-bit quantized) from Hugging
   Face, so it needs internet and can take a few minutes — the menu bar icon and its
   dropdown show live download progress while that happens.

Working on the sidecar itself and want the app to use your own checkout instead of the
bundled copy? Clone [lauronflow-sidecar](https://github.com/lauronjohn/lauronflow-sidecar)
and point the app at it with `./configure-sidecar.sh /path/to/lauronflow-sidecar`
(`configure-sidecar.sh` is in this repo).

## Option B: Build from source

Prerequisites:
```
xcode-select --install          # Xcode command line tools (or install Xcode from the App Store)
brew install xcodegen uv ffmpeg
```

Building requires a local code-signing certificate (self-signed, no Apple Developer
account needed) — this is what lets macOS remember your Accessibility/Microphone grants
across rebuilds instead of re-prompting every time. One-time setup:

1. Open **Keychain Access** → menu **Certificate Assistant → Create a Certificate…**
2. Name: `LauronFlow Local Dev`, Identity Type: **Self Signed Root**, Certificate Type:
   **Code Signing**. Create it, leave everything else default.

Then:
```
git clone https://github.com/lauronjohn/LauronFlow.git LauronFlow
git clone https://github.com/lauronjohn/lauronflow-sidecar.git LauronFlow/sidecar
cd LauronFlow
./install.sh
```

`install.sh` generates the Xcode project, builds, code-signs, and installs to
`/Applications/LauronFlow.app`, and records this checkout's `sidecar/` path so the app
can find it. Re-run it any time you pull new changes.

Same first-launch flow as Option A: the onboarding window, then the Microphone +
Accessibility permission prompts.

## Using it

- Hold **Right Option (⌥)** (configurable), speak, release — the transcript is typed
  wherever your cursor is focused. A floating widget shows a live waveform while
  recording, and the menu bar icon shows live download/loading progress on first launch.
  Prefer not to hold the key down? Switch to **Toggle** mode in Settings → Shortcuts:
  tap once to start, tap again to stop.
- An undo hotkey (default **⌃ Control + ⌥ Option + Z**, configurable) removes the last
  thing LauronFlow typed, in case a transcription is wrong.
- The menu bar dropdown shows a **"N words · N sessions today"** counter and a
  **Recent Transcripts** submenu with your last 20 dictations — each with a timestamp,
  the app it was typed into, and a one-click copy button — plus a Clear History action.
- Menu bar icon shows state (idle / starting up / recording / transcribing / error) and
  has a **Settings…** window with five panes:
  - **General** — Launch at Login, show/hide the floating recording widget, and a quick
    on/off switch for vocabulary replacements.
  - **Vocabulary** — a custom find/replace list for words the model consistently
    mishears (names, jargon, etc.), applied before the transcript is typed. Each entry
    can apply everywhere or be scoped to one specific app.
  - **Excluded Apps** — pick apps where the floating waveform widget should stay
    hidden while recording (dictation itself still works there — this only hides the
    overlay).
  - **Shortcuts** — pick your own record and undo key combos, and choose Hold vs.
    Toggle recording mode. Changes apply immediately, no restart needed.
  - **License** — trial days remaining, license key activation, and a "Buy License…"
    link.

## Troubleshooting

- **Nothing happens when I hold the hotkey / no menu bar icon appears:** check
  `~/Library/Application Support/LauronFlow/sidecar.log` for sidecar startup errors.
- **"Could not locate the `uv` executable":** `uv` isn't on `PATH` — install it with
  `brew install uv` (or check `SidecarPaths.swift`'s `resolveUvExecutable()` for the
  paths it searches).
- **Transcribed but couldn't type it:** grant Accessibility permission in System
  Settings → Privacy & Security → Accessibility, and make sure no secure input field
  (e.g. a password box) has focus.
- **Dictation just stopped working after a couple weeks:** the 14-day trial likely
  ended — check Settings → License.
