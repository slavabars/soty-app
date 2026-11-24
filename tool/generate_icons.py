#!/usr/bin/env python3
"""Generates the Soty app icons from code (no binary sources checked in).

The mark is a honeycomb cell wired to three neighbours: a pointy-top hexagon
with a centre node and alternating node spokes, on a teal-to-indigo gradient.

Run from the repo root:

    python3 tool/generate_icons.py

Writes Android legacy + adaptive-foreground mipmaps, web icons, and the iOS,
macOS, Windows and Linux icon sets.
"""

from __future__ import annotations

import math
import os
from PIL import Image, ImageDraw

TEAL = (13, 148, 136)    # #0D9488
INDIGO = (67, 56, 202)   # #4338CA
SS = 4                   # supersampling factor for anti-aliasing


def _gradient(size: int) -> Image.Image:
    denom = 2 * size - 2
    pixels = []
    for y in range(size):
        for x in range(size):
            t = (x + y) / denom
            pixels.append((
                round(TEAL[0] + (INDIGO[0] - TEAL[0]) * t),
                round(TEAL[1] + (INDIGO[1] - TEAL[1]) * t),
                round(TEAL[2] + (INDIGO[2] - TEAL[2]) * t),
            ))
    img = Image.new("RGB", (size, size))
    img.putdata(pixels)
    return img


def _glyph_layer(size: int, radius_frac: float = 0.30) -> Image.Image:
    s = size * SS
    layer = Image.new("RGBA", (s, s))
    draw = ImageDraw.Draw(layer)
    cx = cy = s / 2
    r = radius_frac * s
    angles = [math.radians(a) for a in (-90, -30, 30, 90, 150, 210)]
    verts = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in angles]

    line_w = max(1, round(0.045 * s))
    draw.line(verts + [verts[0]], fill=(255, 255, 255, 255), width=line_w,
              joint="curve")

    spoke_w = max(1, round(0.030 * s))
    node_r = 0.052 * s
    for index in (0, 2, 4):
        vx, vy = verts[index]
        draw.line([(cx, cy), (vx, vy)], fill=(255, 255, 255, 255),
                  width=spoke_w)
        draw.ellipse([vx - node_r, vy - node_r, vx + node_r, vy + node_r],
                     fill=(255, 255, 255, 255))

    centre_r = 0.078 * s
    draw.ellipse([cx - centre_r, cy - centre_r, cx + centre_r, cy + centre_r],
                 fill=(255, 255, 255, 255))
    return layer.resize((size, size), Image.Resampling.LANCZOS)


def _rounded_mask(size: int, radius_frac: float = 0.22) -> Image.Image:
    s = size * SS
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, s - 1, s - 1], radius=int(radius_frac * s), fill=255
    )
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def full_icon(size: int, *, rounded: bool = True,
              background: bool = True) -> Image.Image:
    if background:
        canvas = _gradient(size).convert("RGBA")
        if rounded:
            canvas.putalpha(_rounded_mask(size))
    else:
        canvas = Image.new("RGBA", (size, size))
    radius_frac = 0.30 if background else 0.29
    return Image.alpha_composite(canvas, _glyph_layer(size, radius_frac))


def _save(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  {path} ({img.width}x{img.height})")


def main() -> None:
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

    android = "android/app/src/main/res"
    for density, px in {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96,
        "xxhdpi": 144, "xxxhdpi": 192,
    }.items():
        _save(full_icon(px), f"{android}/mipmap-{density}/ic_launcher.png")
    for density, px in {
        "mdpi": 108, "hdpi": 162, "xhdpi": 216,
        "xxhdpi": 324, "xxxhdpi": 432,
    }.items():
        _save(
            full_icon(px, rounded=False, background=False),
            f"{android}/mipmap-{density}/ic_launcher_foreground.png",
        )

    _save(full_icon(32, rounded=False), "web/favicon.png")
    _save(full_icon(192), "web/icons/Icon-192.png")
    _save(full_icon(512), "web/icons/Icon-512.png")
    _save(full_icon(192, rounded=False), "web/icons/Icon-maskable-192.png")
    _save(full_icon(512, rounded=False), "web/icons/Icon-maskable-512.png")

    ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, px in {
        "Icon-App-20x20@1x": 20, "Icon-App-20x20@2x": 40,
        "Icon-App-20x20@3x": 60, "Icon-App-29x29@1x": 29,
        "Icon-App-29x29@2x": 58, "Icon-App-29x29@3x": 87,
        "Icon-App-40x40@1x": 40, "Icon-App-40x40@2x": 80,
        "Icon-App-40x40@3x": 120, "Icon-App-60x60@2x": 120,
        "Icon-App-60x60@3x": 180, "Icon-App-76x76@1x": 76,
        "Icon-App-76x76@2x": 152, "Icon-App-83.5x83.5@2x": 167,
        "Icon-App-1024x1024@1x": 1024,
    }.items():
        _save(full_icon(px, rounded=False), f"{ios}/{name}.png")

    macos = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for px in (16, 32, 64, 128, 256, 512, 1024):
        _save(full_icon(px, rounded=False), f"{macos}/app_icon_{px}.png")

    ico = full_icon(256, rounded=False)
    os.makedirs("windows/runner/resources", exist_ok=True)
    ico.save("windows/runner/resources/app_icon.ico",
             sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64),
                    (128, 128), (256, 256)])
    print("  windows/runner/resources/app_icon.ico")

    # Linux: единственная PNG идёт как Flutter-asset (попадает в
    # data/flutter_assets/assets/soty_icon.png), откуда GTK-раннер берёт её и
    # для иконки окна, и для трея (масштабируя под размер трея).
    _save(full_icon(256), "assets/soty_icon.png")


if __name__ == "__main__":
    main()
