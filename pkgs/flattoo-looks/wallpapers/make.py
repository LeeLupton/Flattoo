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


# Soft colour blobs on a light or dark base, like a phone's stock wallpaper.
BLOBS = {
    "home": ((238, 240, 248), [((0.20, 0.25), (120, 160, 255), 0.55), ((0.80, 0.30), (255, 150, 190), 0.50),
                               ((0.55, 0.85), (140, 220, 200), 0.55), ((0.10, 0.90), (255, 205, 130), 0.40)]),
    "home-dark": ((18, 20, 30), [((0.25, 0.30), (70, 90, 210), 0.65), ((0.80, 0.25), (190, 70, 150), 0.55),
                                 ((0.60, 0.85), (40, 160, 150), 0.55), ((0.15, 0.85), (210, 120, 60), 0.40)]),
}


def make_blobs(name, base, blobs):
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    img = np.ones((H, W, 3), np.float32) * np.array(base, np.float32)
    for (bx, by), colour, size in blobs:
        d2 = ((x / W - bx) ** 2 + ((y / H - by) ** 2) * (H / W) ** 2 * 1.4)
        w = np.exp(-d2 / (2 * (size * 0.33) ** 2))
        img += (np.array(colour, np.float32) - np.array(base, np.float32))[None, None, :] * (w * 0.9)[..., None]
    pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(W / 40))
    pil.save(f"{out}/{name}.png", optimize=True)


for name, (base, blobs) in BLOBS.items():
    make_blobs(name, base, blobs)
    print(name)
