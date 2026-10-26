#!/usr/bin/env python3
"""Build the Flattoo wiki: markdown pages with front matter -> static HTML + index.json.

    build.py PAGES_DIR SCREENSHOTS_DIR OUT_DIR [--version TEXT]

PAGES_DIR        wiki/pages/*.md  (YAML front matter, markdown body)
SCREENSHOTS_DIR  wiki/screenshots/*.png + index.json ({file, caption} list from the VM run)
OUT_DIR          html pages, index.html, index.json (metadata for the copilot), img/, thumbs/

index.json is the machine-readable side: one record per page with id, title,
summary, category, tags, questions, actions, menu, shortcuts, screenshots
(file + caption), related, and the html path. Ask Flattoo matches requests
against it and opens the page; the LLM (if enabled) sees titles and summaries.
"""
import argparse
import html
import json
import os
import re
import shutil
import sys

import markdown
import yaml
from PIL import Image

REQUIRED = ("id", "title", "summary", "category", "tags", "questions")
CATEGORIES = {
    "desktop": "The desktop",
    "drawing": "Drawing",
    "printing": "Stencils and printers",
    "phone": "Phone and files",
    "system": "Wi-Fi, updates, power",
    "safety": "Safety",
}

CSS = """
:root{--bg:#fbfaf7;--fg:#1d1d1b;--muted:#5d5c58;--card:#fff;--line:#e4e1da;--accent:#2b6cb0;--chip:#eef2f7;--max:860px}
@media (prefers-color-scheme:dark){:root{--bg:#191a1c;--fg:#e8e6e1;--muted:#a3a19a;--card:#222326;--line:#33353a;--accent:#7fb3ff;--chip:#2a2d33}}
*{box-sizing:border-box}html{font-size:18px}
body{margin:0;background:var(--bg);color:var(--fg);font:1rem/1.55 Inter,"Segoe UI",Roboto,system-ui,sans-serif}
a{color:var(--accent)}main{max-width:var(--max);margin:0 auto;padding:1.2rem 1rem 4rem}
header.top{border-bottom:1px solid var(--line);background:var(--card)}
header.top .in{max-width:var(--max);margin:0 auto;padding:.7rem 1rem;display:flex;gap:1rem;align-items:center;flex-wrap:wrap}
header.top a.home{font-weight:700;text-decoration:none;color:var(--fg)}header.top .cat{color:var(--muted)}
h1{font-size:2rem;line-height:1.2;margin:.4rem 0 .3rem}h2{font-size:1.35rem;margin:1.8rem 0 .5rem;border-bottom:1px solid var(--line);padding-bottom:.2rem}
p.summary{font-size:1.15rem;color:var(--muted);margin:.2rem 0 1rem}
.say{margin:.6rem 0 1.4rem;display:flex;flex-wrap:wrap;gap:.4rem;align-items:center}.say .lbl{color:var(--muted);font-size:.9rem;margin-right:.2rem}
.chip{background:var(--chip);border:1px solid var(--line);border-radius:999px;padding:.15rem .7rem;font-size:.9rem}
table{border-collapse:collapse;width:100%;margin:.6rem 0 1rem}td,th{border:1px solid var(--line);padding:.5rem .6rem;vertical-align:top;text-align:left}th{background:var(--chip)}
code{background:var(--chip);padding:.05rem .35rem;border-radius:4px;font-size:.92em}
figure{margin:1.2rem 0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:.6rem}
figure img{width:100%;height:auto;border-radius:6px;display:block}figcaption{color:var(--muted);font-size:.92rem;padding:.5rem .2rem 0}
figure.pending{border-style:dashed;color:var(--muted);text-align:center;padding:2rem 1rem}
.related{margin-top:2.2rem;border-top:1px solid var(--line);padding-top:.8rem}.related a{margin-right:1rem}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:1rem;margin:1rem 0 2rem}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;overflow:hidden;text-decoration:none;color:var(--fg);display:flex;flex-direction:column}
.card img{width:100%;aspect-ratio:16/9;object-fit:cover;display:block;background:var(--chip)}.card .ph{aspect-ratio:16/9;background:var(--chip)}
.card .t{padding:.7rem .8rem .2rem;font-weight:700}.card .s{padding:0 .8rem .8rem;color:var(--muted);font-size:.92rem}
footer{color:var(--muted);font-size:.85rem;margin-top:3rem}
@media (max-width:600px){html{font-size:17px}h1{font-size:1.6rem}}
"""

PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} · Flattoo</title>
<meta name="description" content="{summary}">
<meta name="flattoo:id" content="{id}"><meta name="flattoo:category" content="{category}"><meta name="flattoo:tags" content="{tags}">
<link rel="stylesheet" href="wiki.css"></head>
<body><header class="top"><div class="in"><a class="home" href="index.html">Flattoo help</a><span class="cat">{catname}</span></div></header>
<main>
<h1>{title}</h1>
<p class="summary">{summary}</p>
{say}
{body}
{figures}
{related}
<footer>Flattoo wiki · {version}</footer>
</main></body></html>
"""

INDEX = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Flattoo help</title><link rel="stylesheet" href="wiki.css"></head>
<body><header class="top"><div class="in"><a class="home" href="index.html">Flattoo help</a><span class="cat">everything about this laptop, in plain words</span></div></header>
<main>
<h1>How do I…</h1>
<p class="summary">Pick a topic, or ask Flattoo (the speech bubble next to the menu, or Super+Space) — it opens the right page.</p>
{sections}
<footer>Flattoo wiki · {version}</footer>
</main></body></html>
"""


def parse(path):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        sys.exit(f"{path}: no front matter")
    meta = yaml.safe_load(m.group(1)) or {}
    for k in REQUIRED:
        if k not in meta or meta[k] in (None, "", []):
            sys.exit(f"{path}: front matter missing {k}")
    for k in ("actions", "menu", "shortcuts", "screenshots", "related"):
        meta.setdefault(k, [])
    meta["body_md"] = m.group(2)
    return meta


def thumb(src, dst, width=480):
    im = Image.open(src)
    im.thumbnail((width, width))
    im.save(dst, "PNG", optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pages")
    ap.add_argument("screenshots")
    ap.add_argument("out")
    ap.add_argument("--version", default="")
    a = ap.parse_args()
    os.makedirs(os.path.join(a.out, "img"), exist_ok=True)
    os.makedirs(os.path.join(a.out, "thumbs"), exist_ok=True)

    captions = {}
    idx = os.path.join(a.screenshots, "index.json")
    if os.path.exists(idx):
        for e in json.load(open(idx)):
            captions[os.path.splitext(e["file"])[0]] = e.get("caption", "")
    have = {os.path.splitext(f)[0] for f in os.listdir(a.screenshots) if f.endswith(".png")} if os.path.isdir(a.screenshots) else set()

    pages = [parse(os.path.join(a.pages, f)) for f in sorted(os.listdir(a.pages)) if f.endswith(".md")]
    ids = [p["id"] for p in pages]
    if len(ids) != len(set(ids)):
        sys.exit("duplicate page ids")
    idset = set(ids)
    missing = set()
    index = []
    md = markdown.Markdown(extensions=["tables", "sane_lists"])

    for p in pages:
        for r in p["related"]:
            if r not in idset:
                sys.exit(f"{p['id']}: related page {r} does not exist")
        body = md.reset().convert(p["body_md"])
        figs = []
        shots = []
        for sid in p["screenshots"]:
            cap = captions.get(sid, sid.replace("-", " "))
            if sid in have:
                src = os.path.join(a.screenshots, sid + ".png")
                shutil.copy(src, os.path.join(a.out, "img", sid + ".png"))
                thumb(src, os.path.join(a.out, "thumbs", sid + ".png"))
                figs.append(f'<figure><img src="img/{sid}.png" alt="{html.escape(cap)}" loading="lazy"><figcaption>{html.escape(cap)}</figcaption></figure>')
                shots.append({"id": sid, "file": f"img/{sid}.png", "thumb": f"thumbs/{sid}.png", "caption": cap})
            else:
                missing.add(sid)
                figs.append(f'<figure class="pending">Screenshot “{html.escape(sid)}” is on its way.</figure>')
                shots.append({"id": sid, "file": None, "thumb": None, "caption": cap})
        say = ""
        if p["questions"]:
            chips = "".join(f'<span class="chip">“{html.escape(q)}”</span>' for q in p["questions"][:4])
            say = f'<div class="say"><span class="lbl">Say to Ask Flattoo:</span>{chips}</div>'
        related = ""
        if p["related"]:
            byid = {q["id"]: q for q in pages}
            links = "".join(f'<a href="{r}.html">{html.escape(byid[r]["title"])}</a>' for r in p["related"])
            related = f'<div class="related"><strong>See also</strong><br>{links}</div>'
        out = PAGE.format(
            title=html.escape(p["title"]), summary=html.escape(p["summary"]), id=p["id"], category=p["category"],
            catname=html.escape(CATEGORIES.get(p["category"], p["category"])), tags=html.escape(", ".join(p["tags"])),
            say=say, body=body, figures="\n".join(figs), related=related, version=html.escape(a.version),
        )
        with open(os.path.join(a.out, p["id"] + ".html"), "w", encoding="utf-8") as f:
            f.write(out)
        index.append({
            "id": p["id"], "title": p["title"], "summary": p["summary"], "category": p["category"],
            "order": p.get("order", 999), "tags": p["tags"], "questions": p["questions"], "actions": p["actions"],
            "menu": p["menu"], "shortcuts": p["shortcuts"], "screenshots": shots, "related": p["related"],
            "html": p["id"] + ".html",
        })

    index.sort(key=lambda e: (e["order"], e["title"]))
    sections = []
    for cat, name in CATEGORIES.items():
        cards = []
        for e in index:
            if e["category"] != cat:
                continue
            t = next((s["thumb"] for s in e["screenshots"] if s["thumb"]), None)
            img = f'<img src="{t}" alt="" loading="lazy">' if t else '<div class="ph"></div>'
            cards.append(f'<a class="card" href="{e["html"]}">{img}<div class="t">{html.escape(e["title"])}</div><div class="s">{html.escape(e["summary"])}</div></a>')
        if cards:
            sections.append(f"<h2>{html.escape(name)}</h2><div class=\"grid\">{''.join(cards)}</div>")
    with open(os.path.join(a.out, "index.html"), "w", encoding="utf-8") as f:
        f.write(INDEX.format(sections="\n".join(sections), version=html.escape(a.version)))
    with open(os.path.join(a.out, "wiki.css"), "w") as f:
        f.write(CSS)
    with open(os.path.join(a.out, "index.json"), "w", encoding="utf-8") as f:
        json.dump({"version": a.version, "pages": index, "missing_screenshots": sorted(missing)}, f, indent=2, ensure_ascii=False)
    print(f"{len(index)} pages, {len(have)} screenshots, {len(missing)} pending: {' '.join(sorted(missing))}")


if __name__ == "__main__":
    main()
