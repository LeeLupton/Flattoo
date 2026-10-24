"""Shared helpers for the Flattoo stencil tools.

Everything physical is in inches at 300 dpi. A Letter page is 2550 x 3300 px,
A4 is 2480 x 3508 px. Images are placed at exact size and the PDF carries
300 dpi metadata, so CUPS prints 1:1 as long as the queue has print-scaling
set to none (stencil-queue-setup does that).
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageOps

Image.MAX_IMAGE_PIXELS = None

DPI = 300
MARGIN_IN = 0.5
QUEUE = os.environ.get("FLATTOO_QUEUE", "Stencil")

PAGE_SIZES_IN = {
    "Letter": (8.5, 11.0),
    "A4": (8.2677, 11.6929),
    "Legal": (8.5, 14.0),
}
# CUPS/IPP media names for `lp -o media=`
MEDIA_NAMES = {"Letter": "Letter", "A4": "A4", "Legal": "Legal"}

RASTER_EXT = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff", ".gif", ".pbm", ".pgm", ".ppm"}


class StencilError(Exception):
    pass


def log(*a):
    print(*a, file=sys.stderr)


# --------------------------------------------------------------------------- input

def rasterize(path: Path) -> tuple[Image.Image, float | None]:
    """Open anything the artist might drop on us.

    Returns (image, dpi). dpi is None when the file has no physical size
    information (phone photos, most PNGs). PDF/SVG/HEIC and anything Pillow
    cannot read go through ImageMagick at 300 dpi.
    """
    path = Path(path)
    if not path.exists():
        raise StencilError(f"{path}: no such file")

    if path.suffix.lower() in RASTER_EXT:
        try:
            img = Image.open(path)
            img.load()
            dpi = img.info.get("dpi")
            dpi_val = None
            if dpi:
                x = float(dpi[0]) if isinstance(dpi, (tuple, list)) else float(dpi)
                # 72 and 96 are "unknown" defaults from apps that write them unconditionally.
                if x > 1 and x not in (72.0, 96.0):
                    dpi_val = x
            return img, dpi_val
        except Exception as e:  # noqa: BLE001
            log(f"Pillow could not read {path.name} ({e}); trying ImageMagick")

    magick = shutil.which("magick") or shutil.which("convert")
    if not magick:
        raise StencilError(f"cannot open {path.name}: ImageMagick is not installed")
    # [0] = first page of a PDF; harmless for other formats.
    cmd = [magick, "-density", str(DPI), f"{path}[0]", "-background", "white",
           "-alpha", "remove", "-alpha", "off", "-colorspace", "Gray", "png:-"]
    try:
        out = subprocess.run(cmd, check=True, capture_output=True).stdout
    except subprocess.CalledProcessError as e:
        raise StencilError(f"ImageMagick failed on {path.name}: {e.stderr.decode(errors='replace')[:400]}")
    import io
    img = Image.open(io.BytesIO(out))
    img.load()
    # Vector or paged input was rendered at exactly DPI; raster input keeps its pixels.
    vector = path.suffix.lower() in {".pdf", ".svg", ".svgz", ".eps", ".ai"}
    return img, (float(DPI) if vector else None)


def gray_on_white(img: Image.Image) -> Image.Image:
    """Flatten transparency onto white and return an 8-bit grayscale image."""
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        bg = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
        bg.alpha_composite(rgba)
        img = bg.convert("RGB")
    if img.mode == "1":
        return img.convert("L")
    if img.mode == "I;16" or img.mode == "I":
        return ImageOps.autocontrast(img.convert("I").point(lambda v: v / 256).convert("L"))
    return img.convert("L")


def threshold(img_l: Image.Image, level: int = 128) -> Image.Image:
    """8-bit gray -> 1-bit. Pixels darker than `level` become black."""
    return img_l.point(lambda v: 255 if v >= level else 0, mode="1")


# --------------------------------------------------------------------------- layout

@dataclass
class Placement:
    page: str
    page_px: tuple[int, int]
    design_in: tuple[float, float]
    design_px: tuple[int, int]
    mirrored: bool
    shrunk: bool


def printable_in(page: str) -> tuple[float, float]:
    w, h = PAGE_SIZES_IN[page]
    return (w - 2 * MARGIN_IN, h - 2 * MARGIN_IN)


def compose_page(design: Image.Image, page: str, width_in: float | None, height_in: float | None,
                 mirror: bool, fit: bool, native_dpi: float | None) -> tuple[Image.Image, Placement]:
    """Scale `design` to a physical size and place it top-centre on a blank page.

    Priority: explicit width -> explicit height -> native dpi -> assume 300 dpi.
    `fit` lets an oversize design shrink to the printable area instead of failing.
    """
    pw_in, ph_in = PAGE_SIZES_IN[page]
    page_px = (round(pw_in * DPI), round(ph_in * DPI))
    max_w_in, max_h_in = printable_in(page)

    src_w, src_h = design.size
    aspect = src_h / src_w

    if width_in:
        w_in = float(width_in)
        h_in = w_in * aspect
    elif height_in:
        h_in = float(height_in)
        w_in = h_in / aspect
    else:
        dpi = native_dpi or float(DPI)
        w_in, h_in = src_w / dpi, src_h / dpi

    shrunk = False
    if w_in > max_w_in or h_in > max_h_in:
        if not fit:
            raise StencilError(
                f"design is {w_in:.2f} x {h_in:.2f} in; printable area on {page} is "
                f"{max_w_in:.2f} x {max_h_in:.2f} in. Use --fit or a smaller --width.")
        s = min(max_w_in / w_in, max_h_in / h_in)
        w_in, h_in = w_in * s, h_in * s
        shrunk = True

    target = (max(1, round(w_in * DPI)), max(1, round(h_in * DPI)))
    scaled = design.resize(target, Image.Resampling.LANCZOS) if target != design.size else design
    if mirror:
        scaled = ImageOps.mirror(scaled)

    page_img = Image.new("L", page_px, 255)
    x = (page_px[0] - target[0]) // 2
    y = round(MARGIN_IN * DPI)
    page_img.paste(scaled, (x, y))
    return page_img, Placement(page, page_px, (w_in, h_in), target, mirror, shrunk)


def save_pdf(page_img: Image.Image, out: Path, bilevel: bool = True):
    img = page_img.convert("1") if bilevel else page_img.convert("L")
    img.save(out, "PDF", resolution=float(DPI))


# --------------------------------------------------------------------------- CUPS

def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, text=True, capture_output=True, **kw)


def queue_exists(queue: str = QUEUE) -> bool:
    return shutil.which("lpstat") is not None and run(["lpstat", "-p", queue]).returncode == 0


def list_queues() -> list[str]:
    """Names of all CUPS queues that accept jobs."""
    out = run(["lpstat", "-a"])
    if out.returncode != 0:
        return []
    return [line.split()[0] for line in out.stdout.splitlines() if " accepting " in line]


def queue_options(queue: str = QUEUE) -> dict[str, tuple[str, list[str]]]:
    """Parse `lpoptions -l`: {option: (default, [choices])}."""
    out = run(["lpoptions", "-p", queue, "-l"])
    opts: dict[str, tuple[str, list[str]]] = {}
    if out.returncode != 0:
        return opts
    for line in out.stdout.splitlines():
        if ":" not in line:
            continue
        head, choices = line.split(":", 1)
        name = head.split("/", 1)[0].strip()
        vals = choices.split()
        default = next((v[1:] for v in vals if v.startswith("*")), vals[0] if vals else "")
        opts[name] = (default, [v.lstrip("*") for v in vals])
    return opts


def queue_page_size(queue: str = QUEUE) -> str:
    default, choices = queue_options(queue).get("PageSize", ("Letter", []))
    if default in PAGE_SIZES_IN:
        return default
    for c in ("Letter", "A4"):
        if c in choices:
            return c
    return "Letter"


def print_pdf(pdf: Path, queue: str, page: str, copies: int = 1, bilevel: bool = True, title: str | None = None) -> str:
    """Send to CUPS with scaling disabled. Returns the job id line from lp."""
    opts = queue_options(queue)
    cmd = ["lp", "-d", queue, "-n", str(copies),
           "-o", f"media={MEDIA_NAMES.get(page, page)}",
           "-o", "print-scaling=none",
           "-o", "print-color-mode=monochrome"]
    # Brother PJ: binary halftone for line work, dither when shading is kept.
    if "BrHalftonePattern" in opts:
        cmd += ["-o", "BrHalftonePattern=" + ("BrBinary" if bilevel else "BrDither")]
    if "BrMirror" in opts:
        cmd += ["-o", "BrMirror=OFF"]  # mirroring, when asked for, is done in software
    if title:
        cmd += ["-t", title[:60]]
    cmd.append(str(pdf))
    r = run(cmd)
    if r.returncode != 0:
        raise StencilError(f"lp failed: {r.stderr.strip() or r.stdout.strip()}")
    return r.stdout.strip()


# --------------------------------------------------------------------------- GUI bits

def have_gui() -> bool:
    return bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")) and shutil.which("zenity") is not None


def zenity(*args: str) -> tuple[int, str]:
    r = run(["zenity", *args])
    return r.returncode, r.stdout.strip()


def notify(summary: str, body: str = "", icon: str = "document-print"):
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "-i", icon, "-a", "Flattoo", summary, body], check=False)


def gui_error(msg: str):
    if have_gui():
        zenity("--error", "--title=Stencil", f"--text={msg}", "--width=380")
    log("error:", msg)


def pick_file(title: str) -> Path | None:
    rc, out = zenity("--file-selection", f"--title={title}",
                     "--file-filter=Images and PDFs | *.png *.jpg *.jpeg *.webp *.heic *.heif *.avif *.bmp *.tif *.tiff *.gif *.svg *.pdf",
                     "--file-filter=All files | *")
    return Path(out) if rc == 0 and out else None
