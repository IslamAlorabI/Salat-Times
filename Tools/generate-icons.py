#!/usr/bin/env python3
"""Generate the macOS AppIcon set and the menu bar template glyph from the brand SVG.

The source SVG is an Android-style full-bleed square. A macOS icon is three layers:

  1. a rounded tile occupying 824/1024 of the canvas,
  2. the glyph inset within that tile with generous padding,
  3. a soft drop shadow outside the tile.

Two details are worth knowing, because both produced visible defects:

* The tile is **painted here**, not taken from the SVG. The SVG's background rect stops
  ~0.5px short of its own viewBox, so the rendered square has a transparent hairline at
  the edges. Forcing alpha onto that (rather than compositing over a solid tile) turned
  invisible transparent-black into an opaque black line around the icon.
* The corner curve and the shadow are **sampled from a stock system icon** rather than
  approximated. Apple's outline is a continuous-corner rounded rectangle; fitting a
  superellipse to it lands ~20% off on the corner and reads as "too square".

Run via Tools/generate-icons.sh, which produces the sampled mask first.
"""
import json
import re
import sys
from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageChops

REPO = Path(__file__).resolve().parent.parent
SVG = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / "Tools" / "SalatTimesLogo.svg"
MASK_SOURCE = Path(sys.argv[2]) if len(sys.argv) > 2 else REPO / "Tools" / "mask-source.png"
ASSETS = REPO / "Salat-Times" / "Assets.xcassets"

CANVAS = 1024
BODY = 824                 # Apple's tile size within a 1024 canvas
GLYPH_FRACTION = 0.78      # glyph's longest side, as a fraction of the tile.
                           # 0.60 left too much air; the source art is full-bleed,
                           # so this keeps the Android icon's presence while still
                           # clearing the rounded corners.
BRAND = (15, 89, 139)      # #0f598b, sampled from the SVG
MENU_BAR_POINTS = 18       # 16 merges the arches into a blob at 1x

SUPERSAMPLE = 4            # render big, downsample once, for clean edges
svg_text = SVG.read_text(encoding="utf-8")


def render(svg: str, width: int, height: int) -> Image.Image:
    png = cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=width, output_height=height)
    return Image.open(BytesIO(png)).convert("RGBA")


def glyph_only(svg: str) -> str:
    """The mosque with the background square removed."""
    return re.sub(r'<path class="st0"[^/]*/>', "", svg)


def sampled_layers(size: int):
    """Apple's tile silhouette and its drop shadow, from a stock icon."""
    src = Image.open(MASK_SOURCE).convert("RGBA")
    alpha = src.getchannel("A")
    # The tile edge steps 255 -> ~64 in one pixel; the soft remainder is the shadow.
    solid = alpha.point(lambda v: 255 if v > 128 else 0)
    bbox = solid.getbbox()

    tile = solid.crop(bbox).resize((size, size), Image.LANCZOS)
    # Shadow = everything the stock icon draws *outside* its tile.
    shadow_full = ImageChops.subtract(alpha, solid)
    return tile, shadow_full


# ---------------------------------------------------------------- app icon
hi = BODY * SUPERSAMPLE

# 1. The tile: painted flat, so no hairline can survive at the edges.
tile_rgb = Image.new("RGBA", (hi, hi), BRAND + (255,))

# 2. The glyph, scaled to leave padding, composited *over* the tile (not alpha-forced).
glyph = render(glyph_only(svg_text), hi, hi)
glyph = glyph.crop(glyph.getbbox())
target = int(hi * GLYPH_FRACTION)
if glyph.width >= glyph.height:
    new_size = (target, max(1, round(target * glyph.height / glyph.width)))
else:
    new_size = (max(1, round(target * glyph.width / glyph.height)), target)
glyph = glyph.resize(new_size, Image.LANCZOS)
tile_rgb.alpha_composite(glyph, ((hi - glyph.width) // 2, (hi - glyph.height) // 2))

tile_mask, shadow_full = sampled_layers(hi)
tile = tile_rgb.copy()
tile.putalpha(tile_mask)          # safe now: every pixel underneath is opaque brand blue
tile = tile.resize((BODY, BODY), Image.LANCZOS)

# 3. Shadow underneath, then the tile on top.
master = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
shadow_layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
shadow_layer.putalpha(shadow_full.resize((CANVAS, CANVAS), Image.LANCZOS))
master.alpha_composite(shadow_layer)

offset = (CANVAS - BODY) // 2
master.alpha_composite(tile, (offset, offset))

appicon = ASSETS / "AppIcon.appiconset"
for old in appicon.glob("*.png"):
    old.unlink()

images = []
for pt, scale in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
                  (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]:
    px = pt * scale
    name = f"icon_{pt}x{pt}.png" if scale == 1 else f"icon_{pt}x{pt}@2x.png"
    master.resize((px, px), Image.LANCZOS).save(appicon / name)
    images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})

(appicon / "Contents.json").write_text(
    json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
    encoding="utf-8")
print(f"AppIcon: {len(images)} PNGs (glyph at {GLYPH_FRACTION:.0%} of tile, sampled corners + shadow)")

# ------------------------------------------------------- menu bar template
# AppKit recolours a template image from its alpha, so the fill only has to be opaque.
mono = render(glyph_only(svg_text).replace("fill: #fff;", "fill: #000;"), 1024, 1024)
crop = mono.crop(mono.getbbox())

menubar = ASSETS / "MenuBarIcon.imageset"
menubar.mkdir(exist_ok=True)
for old in menubar.glob("*.png"):
    old.unlink()

glyph_images = []
for scale in (1, 2, 3):
    box = MENU_BAR_POINTS * scale
    if crop.height >= crop.width:
        size = (max(1, round(box * crop.width / crop.height)), box)
    else:
        size = (box, max(1, round(box * crop.height / crop.width)))
    fitted = crop.resize(size, Image.LANCZOS)
    canvas = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((box - fitted.width) // 2, (box - fitted.height) // 2))
    name = f"menubar_{scale}x.png"
    canvas.save(menubar / name)
    glyph_images.append({"filename": name, "idiom": "universal", "scale": f"{scale}x"})

(menubar / "Contents.json").write_text(json.dumps({
    "images": glyph_images,
    "info": {"author": "xcode", "version": 1},
    "properties": {"template-rendering-intent": "template"},
}, indent=2) + "\n", encoding="utf-8")
print(f"MenuBarIcon: {len(glyph_images)} PNGs (template)")
