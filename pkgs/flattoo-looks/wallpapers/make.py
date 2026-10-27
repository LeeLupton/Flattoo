#!/usr/bin/env python3
"""Generate Flattoo's wallpapers, the boot-splash mark and the lock-screen
backdrop. Everything is drawn from numbers: gradients, grain, halftone,
glow, ridgelines, petals. No photos, no art, nothing to clear rights on.
Deterministic (seeded), so a rebuild gives the same pixels.

usage: make.py OUTDIR [WIDTH HEIGHT]
       FLATTOO_FONT=/path/to/display.ttf   (the wordmark; falls back to PIL's font)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = sys.argv[1]
W = int(sys.argv[2]) if len(sys.argv) > 2 else 2560
H = int(sys.argv[3]) if len(sys.argv) > 3 else 1600
FONT = os.environ.get("FLATTOO_FONT")


def seed(name):
    return np.random.default_rng(sum(ord(c) * (i + 1) for i, c in enumerate(name)))


def grid():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    return x, y


def gradient(c0, c1, angle=0.6):
    x, y = grid()
    t = (x / W * angle + y / H * (1 - angle))[..., None]
    return np.array(c0, np.float32) * (1 - t) + np.array(c1, np.float32) * t


def grain(img, rng, strength):
    """Paper grain: blurred noise so it reads as texture, not static."""
    noise = rng.normal(0, 1, (H // 2, W // 2)).astype(np.float32)
    noise = Image.fromarray(np.clip(noise * 40 + 128, 0, 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
    noise = np.array(noise.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) - 128
    return img + (noise / 40 * strength)[..., None]


def vignette(img, amount, start=0.4):
    x, y = grid()
    cx, cy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
    r = np.sqrt(cx * cx + cy * cy)
    return img * (1 - amount * np.clip(r - start, 0, 1) ** 1.5)[..., None]


PNG = {"compress_level": 4}  # optimize=True spends ~95% of the build on zlib; grain does not compress anyway


def save(name, img):
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(f"{out}/{name}.png", **PNG)
    print(name)


def to_pil(img):
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def ridgeline(rng, base, amp, bumps, smooth):
    """A 1-D skyline across the width: layered sines plus smoothed noise."""
    x = np.arange(W, dtype=np.float32)
    y = np.full(W, base, np.float32)
    for k in range(bumps):
        f = rng.uniform(0.6, 2.5) * (k + 1)
        y += amp / (k + 1) * np.sin(x / W * 2 * math.pi * f + rng.uniform(0, 2 * math.pi))
    n = rng.normal(0, 1, W // smooth + 2).astype(np.float32)
    n = np.interp(x, np.linspace(0, W, len(n)), n)
    return y + amp * 0.35 * n


def fill_below(img, line, colour, soft=1.5):
    """Paint everything under a ridgeline with a colour (soft edge)."""
    x, y = grid()
    a = np.clip((y - line[None, :]) / soft, 0, 1)[..., None]
    return img * (1 - a) + np.array(colour, np.float32) * a


# ---------------------------------------------------------------- quiet gradients

PALETTES = {
    # name: (top-left colour, bottom-right colour, grain strength, vignette)
    "slate": ((44, 48, 56), (28, 30, 36), 6, 0.25),
    "paper": ((246, 241, 230), (230, 222, 206), 5, 0.10),
    "ink": ((14, 14, 16), (6, 6, 8), 4, 0.35),
    "blue": ((38, 70, 110), (18, 32, 56), 5, 0.20),
    "ember": ((58, 42, 34), (32, 24, 20), 6, 0.25),
    "sage": ((68, 82, 70), (40, 50, 44), 5, 0.20),
}

for name, (c0, c1, g, vig) in PALETTES.items():
    save(name, vignette(grain(gradient(c0, c1), seed(name), g), vig))


# ---------------------------------------------------------------- phone-style blobs

BLOBS = {
    "home": ((238, 240, 248), [((0.20, 0.25), (120, 160, 255), 0.55), ((0.80, 0.30), (255, 150, 190), 0.50),
                               ((0.55, 0.85), (140, 220, 200), 0.55), ((0.10, 0.90), (255, 205, 130), 0.40)]),
    "home-dark": ((18, 20, 30), [((0.25, 0.30), (70, 90, 210), 0.65), ((0.80, 0.25), (190, 70, 150), 0.55),
                                 ((0.60, 0.85), (40, 160, 150), 0.55), ((0.15, 0.85), (210, 120, 60), 0.40)]),
}


def make_blobs(name, base, blobs):
    x, y = grid()
    img = np.ones((H, W, 3), np.float32) * np.array(base, np.float32)
    for (bx, by), colour, size in blobs:
        d2 = ((x / W - bx) ** 2 + ((y / H - by) ** 2) * (H / W) ** 2 * 1.4)
        w = np.exp(-d2 / (2 * (size * 0.33) ** 2))
        img += (np.array(colour, np.float32) - np.array(base, np.float32))[None, None, :] * (w * 0.9)[..., None]
    pil = to_pil(img).filter(ImageFilter.GaussianBlur(W / 40))
    pil.save(f"{out}/{name}.png", **PNG)
    print(name)


for name, (base, blobs) in BLOBS.items():
    make_blobs(name, base, blobs)


# ---------------------------------------------------------------- blackwork: halftone

def make_halftone():
    """Near-black, a field of ink dots on a tilted grid that grows from
    nothing at the top right to solid shading at the bottom left."""
    rng = seed("halftone")
    x, y = grid()
    img = gradient((20, 20, 23), (9, 9, 11), 0.5)
    ang = math.radians(27)
    cell = 22.0
    u = (x * math.cos(ang) + y * math.sin(ang)) / cell
    v = (-x * math.sin(ang) + y * math.cos(ang)) / cell
    du, dv = u - np.round(u), v - np.round(v)
    d = np.sqrt(du * du + dv * dv)
    t = np.clip(1.15 - (x / W) * 0.9 - (1 - y / H) * 0.9, 0, 1)  # bottom-left = 1
    radius = 0.08 + 0.42 * t ** 1.6
    dot = np.clip((radius - d) / 0.06, 0, 1)
    img += dot[..., None] * np.array((38, 38, 44), np.float32) * 0.9
    img = grain(img, rng, 3)
    save("blackwork", vignette(img, 0.3))


make_halftone()


# ---------------------------------------------------------------- flash sheet: parchment + grid + colour chips

def make_flash():
    rng = seed("flash")
    img = gradient((243, 233, 210), (228, 214, 186), 0.45)
    img = grain(img, rng, 7)
    x, y = grid()
    # a draft grid like the one under a flash sheet
    step = 64
    gx = np.minimum(x % step, step - x % step)
    gy = np.minimum(y % step, step - y % step)
    line = np.clip(1.2 - np.minimum(gx, gy), 0, 1) * 0.16
    heavy = ((np.round(x / step) % 4 == 0) & (gx < 1.2)) | ((np.round(y / step) % 4 == 0) & (gy < 1.2))
    line = np.maximum(line, heavy * 0.28)
    img = img * (1 - line[..., None]) + np.array((176, 150, 110), np.float32) * line[..., None]
    img = vignette(img, 0.18, 0.5)
    pil = to_pil(img)
    d = ImageDraw.Draw(pil, "RGBA")
    # the traditional palette as a test strip, bottom left
    chips = [(178, 58, 50), (215, 167, 63), (47, 107, 79), (27, 26, 25)]
    cw, ch, gap = int(W * 0.055), int(H * 0.028), int(W * 0.012)
    x0, y0 = int(W * 0.07), int(H * 0.86)
    for i, c in enumerate(chips):
        d.rounded_rectangle([x0 + i * (cw + gap), y0, x0 + i * (cw + gap) + cw, y0 + ch], radius=6, fill=c + (235,))
    d.line([x0, y0 + ch + gap, x0 + 4 * cw + 3 * gap, y0 + ch + gap], fill=(27, 26, 25, 140), width=3)
    pil.save(f"{out}/flash.png", **PNG)
    print("flash")


make_flash()


# ---------------------------------------------------------------- neon: glowing tubes on a dark studio wall

def bezier(p0, p1, p2, p3, n=200):
    t = np.linspace(0, 1, n)[:, None]
    pts = ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * (t ** 2) * p2 + (t ** 3) * p3
    return [tuple(p) for p in pts]


def make_neon():
    rng = seed("neon")
    base = to_pil(vignette(grain(gradient((24, 12, 40), (6, 4, 12), 0.3), rng, 4), 0.35))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    tubes = Image.new("RGB", (W, H), (0, 0, 0))
    strokes = [
        ((255, 62, 165), [(0.08, 0.72), (0.30, 0.10), (0.55, 1.05), (0.78, 0.35)]),
        ((55, 229, 255), [(0.20, 0.95), (0.45, 0.25), (0.70, 0.75), (0.96, 0.20)]),
        ((155, 92, 255), [(0.00, 0.35), (0.25, 0.60), (0.60, 0.15), (0.90, 0.80)]),
    ]
    for colour, ctrl in strokes:
        pts = bezier(*[np.array((cx * W, cy * H), np.float32) for cx, cy in ctrl])
        ImageDraw.Draw(glow).line(pts, fill=colour, width=int(W * 0.006), joint="curve")
        ImageDraw.Draw(tubes).line(pts, fill=tuple(min(255, c + 110) for c in colour), width=int(W * 0.0022), joint="curve")
    g = np.zeros((H, W, 3), np.float32)
    for radius, weight in ((W / 160, 0.9), (W / 50, 0.7), (W / 18, 0.55)):
        g += np.array(glow.filter(ImageFilter.GaussianBlur(radius)), np.float32) * weight
    img = np.array(base, np.float32) + g * 0.8 + np.array(tubes.filter(ImageFilter.GaussianBlur(1.2)), np.float32)
    save("neon", img)


make_neon()


# ---------------------------------------------------------------- sakura: petals drifting over a soft dawn / moon sky

def petals(rng, base_img, colours, count, dark):
    pil = to_pil(base_img).convert("RGBA")
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for _ in range(count):
        size = int(rng.uniform(W * 0.012, W * 0.05))
        far = size < W * 0.022
        pet = Image.new("RGBA", (size * 2, size * 2), (0, 0, 0, 0))
        c = colours[rng.integers(len(colours))]
        a = int(rng.uniform(120, 200)) if not far else int(rng.uniform(70, 130))
        d = ImageDraw.Draw(pet)
        d.ellipse([size * 0.5, size * 0.15, size * 1.5, size * 1.85], fill=c + (a,))
        # the notch at a petal's tip
        d.polygon([(size, size * 0.15), (size * 0.86, size * 0.42), (size * 1.14, size * 0.42)], fill=(0, 0, 0, 0))
        pet = pet.rotate(rng.uniform(0, 360), resample=Image.BICUBIC, expand=True)
        if far:
            pet = pet.filter(ImageFilter.GaussianBlur(size * 0.12))
        layer.alpha_composite(pet, (int(rng.uniform(-size, W)), int(rng.uniform(-size, H))))
    pil.alpha_composite(layer)
    return np.array(pil.convert("RGB"), np.float32)


def make_sakura():
    rng = seed("sakura")
    img = gradient((250, 244, 237), (242, 228, 226), 0.35)
    x, y = grid()
    w = np.exp(-(((x / W - 0.78) ** 2) + ((y / H - 0.22) ** 2) * 1.6) / 0.12)
    img += (np.array((255, 214, 200), np.float32) - img) * (w * 0.6)[..., None]
    img = grain(img, rng, 3)
    img = petals(rng, img, [(235, 188, 186), (215, 130, 126), (244, 194, 194), (230, 160, 170)], 70, False)
    save("sakura", vignette(img, 0.08, 0.6))

    rng = seed("sakura-night")
    img = gradient((35, 33, 54), (42, 39, 63), 0.3)
    moon = np.exp(-(((x / W - 0.80) ** 2) + ((y / H - 0.20) ** 2) * 1.6) / 0.01)
    halo = np.exp(-(((x / W - 0.80) ** 2) + ((y / H - 0.20) ** 2) * 1.6) / 0.10)
    img += (np.array((244, 237, 220), np.float32) - img) * np.clip(moon * 1.8, 0, 1)[..., None]
    img += np.array((120, 100, 140), np.float32) * (halo * 0.25)[..., None]
    img = grain(img, rng, 3)
    img = petals(rng, img, [(234, 154, 151), (196, 167, 231), (156, 207, 216), (224, 170, 180)], 60, True)
    save("sakura-night", vignette(img, 0.25))


make_sakura()


# ---------------------------------------------------------------- forest: ridgelines in mist

def make_forest():
    rng = seed("forest")
    img = gradient((86, 99, 102), (52, 62, 66), 0.15)
    x, y = grid()
    sun = np.exp(-(((x / W - 0.3) ** 2) * 0.6 + ((y / H - 0.1) ** 2) * 2.0) / 0.06)
    img += np.array((167, 192, 128), np.float32) * (sun * 0.18)[..., None]
    img = grain(img, rng, 3)
    layers = [(0.50, 0.06, (72, 84, 87)), (0.60, 0.07, (61, 72, 77)), (0.70, 0.08, (52, 63, 68)),
              (0.80, 0.07, (46, 56, 60)), (0.90, 0.06, (39, 46, 51)), (0.98, 0.04, (30, 35, 38))]
    for i, (base, amp, colour) in enumerate(layers):
        line = ridgeline(rng, base * H, amp * H, 3, 60 + i * 20)
        # mist hugging the ridge: lighten just above the line
        mist = np.exp(-np.clip(line[None, :] - y, 0, None) / (H * 0.035)) * 0.35
        img += (np.array((150, 160, 150), np.float32) - img) * mist[..., None]
        img = fill_below(img, line, colour, 2.0)
    save("forest", vignette(img, 0.2, 0.55))


make_forest()


# ---------------------------------------------------------------- kanagawa: deep water, wave crests, a little foam

def make_waves():
    rng = seed("kanagawa")
    img = gradient((36, 40, 59), (22, 22, 29), 0.2)
    x, y = grid()
    img = grain(img, rng, 3)
    layers = [(0.46, (45, 58, 86)), (0.58, (34, 50, 73)), (0.70, (29, 44, 66)), (0.82, (26, 36, 56)), (0.94, (22, 29, 45))]
    for i, (base, colour) in enumerate(layers):
        xs = np.arange(W, dtype=np.float32)
        line = base * H + H * 0.035 * np.sin(xs / W * 2 * math.pi * (2.5 + i * 0.7) + rng.uniform(0, 6)) \
            + H * 0.012 * np.sin(xs / W * 2 * math.pi * (9 + i * 2) + rng.uniform(0, 6))
        crest = np.clip(1 - np.abs(y - line[None, :]) / 3.0, 0, 1)
        img = fill_below(img, line, colour, 2.0)
        img += np.array((200, 192, 147), np.float32) * (crest * (0.55 - i * 0.08))[..., None]
    # foam flecks along the first crest
    pil = to_pil(img)
    d = ImageDraw.Draw(pil, "RGBA")
    for _ in range(140):
        fx = rng.uniform(0, W)
        fy = 0.46 * H + H * 0.035 * math.sin(fx / W * 2 * math.pi * 2.5) + rng.normal(0, H * 0.01)
        r = rng.uniform(1.5, 5)
        d.ellipse([fx - r, fy - r, fx + r, fy + r], fill=(200, 192, 147, int(rng.uniform(80, 180))))
    pil.save(f"{out}/kanagawa.png", **PNG)
    print("kanagawa")


make_waves()


# ---------------------------------------------------------------- the mark: boot splash watermark + lock backdrop

def make_mark():
    """A stencil registration mark and the wordmark, white on transparent
    (plymouth's watermark) and small on the ink backdrop (lock / login)."""
    size = 160
    mark = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(mark)
    s = size / 160
    d.ellipse([10 * s, 10 * s, 150 * s, 150 * s], outline=(255, 255, 255, 235), width=int(9 * s))
    d.ellipse([66 * s, 66 * s, 94 * s, 94 * s], fill=(255, 255, 255, 235))
    for a in (0, 90, 180, 270):
        rad = math.radians(a)
        x0, y0 = 80 * s + math.cos(rad) * 28 * s, 80 * s + math.sin(rad) * 28 * s
        x1, y1 = 80 * s + math.cos(rad) * 60 * s, 80 * s + math.sin(rad) * 60 * s
        d.line([x0, y0, x1, y1], fill=(255, 255, 255, 235), width=int(7 * s))
    font = None
    if FONT and os.path.exists(FONT):
        font = ImageFont.truetype(FONT, 118)
    else:
        font = ImageFont.load_default(size=100)
    text = "flattoo"
    tb = ImageDraw.Draw(mark).textbbox((0, 0), text, font=font)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    pad = 36
    logo = Image.new("RGBA", (size + pad + tw + 8, max(size, th) + 8), (0, 0, 0, 0))
    logo.alpha_composite(mark, (0, (logo.height - size) // 2))
    ImageDraw.Draw(logo).text((size + pad - tb[0], (logo.height - th) // 2 - tb[1]), text, font=font, fill=(255, 255, 255, 240))
    logo.save(f"{out}/flattoo-mark.png", optimize=True)
    print("flattoo-mark")
    # lock / login backdrop: the ink gradient with the mark low and small
    back = Image.open(f"{out}/ink.png").convert("RGBA")
    small = logo.resize((logo.width // 2, logo.height // 2), Image.LANCZOS)
    faded = small.copy()
    faded.putalpha(small.getchannel("A").point(lambda a: int(a * 0.55)))
    back.alpha_composite(faded, (W - small.width - int(W * 0.03), H - small.height - int(H * 0.04)))
    back.convert("RGB").save(f"{out}/lockscreen.png", **PNG)
    print("lockscreen")


make_mark()
