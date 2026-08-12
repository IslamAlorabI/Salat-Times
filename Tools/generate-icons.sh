#!/bin/bash
# Regenerates the app icon and the menu bar glyph from Tools/SalatTimesLogo.svg.
#
#   ./Tools/generate-icons.sh
#
# Needs cairosvg and Pillow (pip3 install cairosvg pillow).
set -euo pipefail
cd "$(dirname "$0")/.."

swift Tools/extract-mask.swift Tools/mask-source.png
python3 Tools/generate-icons.py Tools/SalatTimesLogo.svg Tools/mask-source.png
