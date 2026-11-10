#!/usr/bin/env bash
# Build Cerulean (this private BlueBubbles fork) for Linux inside a throwaway nix shell.
# Output: build/linux/x64/release/bundle/bluebubbles
set -euo pipefail
cd "$(dirname "$0")/.."
# pubspec.yaml lists .env as an asset and the build fails without it; upstream CI writes the same empty placeholder.
echo "KLIPY_API_KEY=" > .env
nix-shell .cerulean/shell.nix --run 'flutter pub get && flutter build linux --release'
echo "Built: $PWD/build/linux/x64/release/bundle/bluebubbles"
