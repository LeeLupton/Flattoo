#!/usr/bin/env python3
"""Generate Flattoo's wallpapers: quiet gradients with a little paper grain.
No photos, no art, nothing to clear rights on. Deterministic (seeded).

usage: make.py OUTDIR [WIDTH HEIGHT]
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

out = sys.argv[1]
W = int(sys.argv[2]) if len(sys.argv) > 2 else 2560
H = int(sys.argv[3]) if len(sys.argv) > 3 else 1600

PALETTES = {
    # name: (top-left colour, bottom-right colour, grain strength, vignette)
    "slate": ((44, 48, 56), (28, 30, 36), 6, 0.25),
    "paper": ((246, 241, 230), (230, 222, 206), 5, 0.10),
    "ink": ((14, 14, 16), (6, 6, 8), 4, 0.35),
    "blue": ((38, 70, 110), (18, 32, 56), 5, 0.20),
    "ember": ((58, 42, 34), (32, 24, 20), 6, 0.25),
    "sage": ((68, 82, 70), (40, 50, 44), 5, 0.20),
}


def make(name, c0, c1, grain, vig):
    rng = np.random.default_rng(abs(hash(name)) % (2**32))
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    t = (x / W * 0.6 + y / H * 0.4)
    t = t[..., None]
    img = np.array(c0, np.float32) * (1 - t) + np.array(c1, np.float32) * t
    # paper grain: blurred noise so it reads as texture, not static
    noise = rng.normal(0, 1, (H // 2, W // 2)).astype(np.float32)
    noise = np.array(Image.fromarray(np.clip(noise * 40 + 128, 0, 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
                     .filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) - 128
    img += (noise / 40 * grain)[..., None]
    # vignette
    cx, cy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
    r = np.sqrt(cx * cx + cy * cy)
    img *= (1 - vig * np.clip(r - 0.4, 0, 1) ** 1.5)[..., None]
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(f"{out}/{name}.png", optimize=True)


for name, (c0, c1, grain, vig) in PALETTES.items():
    make(name, c0, c1, grain, vig)
    print(name)
