#!/bin/bash
# One-time setup for testers using the prebuilt LauronFlow.app from a GitHub Release
# (skip this if you built with install.sh — that already does this step for you).
# Points the installed app at wherever you cloned the lauronflow-sidecar repo.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/lauronflow-sidecar" >&2
  exit 1
fi

SIDECAR_DIR="$(cd "$1" && pwd)"
if [ ! -f "$SIDECAR_DIR/pyproject.toml" ]; then
  echo "$SIDECAR_DIR doesn't look like the lauronflow-sidecar repo (no pyproject.toml)." >&2
  exit 1
fi

SUPPORT_DIR="$HOME/Library/Application Support/LauronFlow"
mkdir -p "$SUPPORT_DIR"
printf '%s' "$SIDECAR_DIR" > "$SUPPORT_DIR/sidecar_path.txt"

echo "Configured. LauronFlow will look for the sidecar at: $SIDECAR_DIR"
echo "(Quit and relaunch LauronFlow if it's already running.)"
