#!/bin/bash
# Behaviour checks for the pure Core types — no network, no side effects.
#
# The Xcode project has no test target (adding one needs a GUI step), so these
# compile the real sources with swiftc and assert against them. Anything in Core/
# worth trusting — timezone resolution, DST, Jumu'ah, rounding — belongs here.
#
#   ./Checks/run.sh            offline checks only
#   ./Checks/run.sh --network  also exercise the Aladhan API and the disk cache
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="Salat Times"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# Everything in Core/ by design compiles without SwiftUI, so glob it rather than
# listing files — a new Core type is then covered automatically.
CORE=("$SRC/Core/"*.swift
      "$SRC/Services/PrayerNotificationScheduler.swift"
      "$SRC/Translations.swift"
      "$SRC"/Translations+*.swift)

swiftc -O -o "$OUT/offline" "${CORE[@]}" Checks/offline/main.swift
"$OUT/offline"

if [[ "${1:-}" == "--network" ]]; then
  echo
  echo "=== network checks (hits api.aladhan.com) ==="
  swiftc -O -o "$OUT/network" \
    "$SRC/Core/"*.swift "$SRC/Data/"*.swift \
    "$SRC/Translations.swift" "$SRC"/Translations+*.swift \
    Checks/network/main.swift
  "$OUT/network"
fi
