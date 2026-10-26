#!/usr/bin/env python3
"""Assemble the GitHub Pages site: landing page + wiki + rendered docs.

    build.py REPO_ROOT WIKI_DIR OUT_DIR --version TEXT --repo OWNER/NAME
"""
import argparse
import html
import os
import re
import shutil

import markdown

CSS = """
:root{--bg:#fbfaf7;--fg:#1d1d1b;--muted:#5d5c58;--card:#fff;--line:#e4e1da;--accent:#2b6cb0;--chip:#eef2f7}
@media (prefers-color-scheme:dark){:root{--bg:#191a1c;--fg:#e8e6e1;--muted:#a3a19a;--card:#222326;--line:#33353a;--accent:#7fb3ff;--chip:#2a2d33}}
*{box-sizing:border-box}html{font-size:17px}body{margin:0;background:var(--bg);color:var(--fg);font:1rem/1.6 Inter,"Segoe UI",Roboto,system-ui,sans-serif}
a{color:var(--accent)}main{max-width:900px;margin:0 auto;padding:1rem 1rem 4rem}
header.top{border-bottom:1px solid var(--line);background:var(--card)}header.top .in{max-width:900px;margin:0 auto;padding:.7rem 1rem;display:flex;gap:1.2rem;align-items:center;flex-wrap:wrap}
header.top a{text-decoration:none;color:var(--fg)}header.top a.b{font-weight:700}
h1{font-size:2.4rem;line-height:1.15;margin:1.2rem 0 .3rem}h2{font-size:1.4rem;margin:2rem 0 .6rem;border-bottom:1px solid var(--line);padding-bottom:.2rem}
p.lead{font-size:1.2rem;color:var(--muted)}
.btn{display:inline-block;background:var(--accent);color:#fff;padding:.7rem 1.2rem;border-radius:10px;text-decoration:none;font-weight:600;margin:.4rem .6rem .4rem 0}
.btn.alt{background:var(--chip);color:var(--fg);border:1px solid var(--line)}
table{border-collapse:collapse;width:100%;margin:.6rem 0 1rem}td,th{border:1px solid var(--line);padding:.5rem .6rem;vertical-align:top;text-align:left}th{background:var(--chip)}
code,pre{background:var(--chip);border-radius:6px}code{padding:.05rem .35rem;font-size:.92em}pre{padding:.8rem;overflow:auto}pre code{padding:0;background:none}
.strip{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:.8rem;margin:1rem 0}
.strip figure{margin:0;background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden}.strip img{width:100%;display:block}.strip figcaption{padding:.5rem .7rem;font-size:.9rem;color:var(--muted)}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:.8rem}.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:1rem;text-decoration:none;color:var(--fg)}.card b{display:block;margin-bottom:.3rem}
footer{color:var(--muted);font-size:.9rem;margin-top:3rem}
blockquote{border-left:3px solid var(--line);margin:1rem 0;padding:.2rem 1rem;color:var(--muted)}
"""

SHELL = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title><meta name="description" content="{desc}"><link rel="stylesheet" href="{root}site.css"></head>
<body><header class="top"><div class="in"><a class="b" href="{root}index.html">Flattoo</a><a href="{root}wiki/index.html">Help &amp; How-To</a><a href="{root}docs/index.html">Docs</a><a href="https://github.com/{repo}">GitHub</a><a href="https://github.com/{repo}/releases/latest">Download</a></div></header>
<main>{body}<footer>Flattoo · {version} · <a href="https://github.com/{repo}">source</a></footer></main></body></html>"""

LANDING = """
<h1>Flattoo</h1>
<p class="lead">A tattoo studio laptop that works like a phone, prints stencils at true size, and looks after itself. NixOS underneath; nobody at the studio needs to know.</p>
<p><a class="btn" href="https://github.com/{repo}/releases/latest">Download the installer</a> <a class="btn alt" href="wiki/index.html">Help &amp; How-To</a> <a class="btn alt" href="docs/install.html">Install guide</a></p>
<p>The installer is a bootable USB image (<code>flattoo-installer-*.iso</code>). Write it to a stick, boot the laptop from it, run <code>flattoo-install</code>: one disk passphrase, one admin password, ten to twenty-five minutes. Check the download against the <code>SHA256SUMS</code> file on the release page before writing it.</p>
{strip}
<h2>What the artist gets</h2>
<div class="cards">
<a class="card" href="wiki/start-here.html"><b>Feels like a phone</b>App icons, a dock, one tap opens things. Familiar names: Files, Photos, Documents.</a>
<a class="card" href="wiki/print-stencil.html"><b>Stencils at true size</b>Right-click a design, type the width in inches. Brother PocketJet and Phomemo by cable, Bluetooth or Wi-Fi.</a>
<a class="card" href="wiki/ask-flattoo.html"><b>Never a terminal</b>Ask Flattoo: "something like Paint", "update now", "the printer isn't working". A fixed set of safe actions behind plain English.</a>
<a class="card" href="wiki/looks.html"><b>Eight looks, five layouts</b>Change everything at once, save your own, lock it when it is right.</a>
<a class="card" href="wiki/assist.html"><b>Looks after your name</b>A portfolio gallery from your photos, a résumé from your profile, a weekly nudge. Nothing posted for you.</a>
<a class="card" href="wiki/safety.html"><b>Safe on any Wi-Fi</b>Encrypted disk, validating encrypted DNS, no listeners, nightly updates with rollback.</a>
</div>
<h2>For whoever maintains it</h2>
<p>Everything is one Git repository: push to <code>main</code> and the laptop pulls it overnight, builds the new system and makes it the boot default; the previous one stays one boot-menu entry away. Start with the <a href="docs/index.html">docs</a>: install, printers, maintenance, looks, the copilot, the network edge, the wiki, assist.</p>
"""


def render_md(text, root):
    md = markdown.Markdown(extensions=["tables", "fenced_code", "toc"])
    body = md.convert(text)
    body = re.sub(r'href="([^"#:]+)\.md(#[^"]*)?"', lambda m: f'href="{m.group(1)}.html{m.group(2) or ""}"', body)
    body = body.replace('href="docs/', f'href="{root}docs/').replace('href="wiki/', f'href="{root}wiki/')
    return body


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo_root"); ap.add_argument("wiki"); ap.add_argument("out")
    ap.add_argument("--version", default="dev"); ap.add_argument("--repo", default="LeeLupton/Flattoo")
    a = ap.parse_args()
    os.makedirs(os.path.join(a.out, "docs"), exist_ok=True)
    shutil.copytree(a.wiki, os.path.join(a.out, "wiki"), dirs_exist_ok=True)
    with open(os.path.join(a.out, "site.css"), "w") as f:
        f.write(CSS)
    open(os.path.join(a.out, ".nojekyll"), "w").close()

    # docs/*.md and README -> docs/
    docs = sorted(f for f in os.listdir(os.path.join(a.repo_root, "docs")) if f.endswith(".md"))
    index_items = []
    for f in docs + ["README.md"]:
        src = os.path.join(a.repo_root, "docs" if f != "README.md" else "", f)
        text = open(src, encoding="utf-8").read()
        m = re.search(r"^#\s+(.+)$", text, re.M)
        title = m.group(1) if m else f
        name = "index" if f == "README.md" else f[:-3]
        body = render_md(text, "../")
        page = SHELL.format(title=html.escape(title) + " · Flattoo", desc=html.escape(title), root="../", repo=a.repo, body=body, version=html.escape(a.version))
        with open(os.path.join(a.out, "docs", name + ".html"), "w", encoding="utf-8") as out:
            out.write(page)
        if f != "README.md":
            index_items.append((name, title))
    # docs index = README with a list of the docs on top
    readme = render_md(open(os.path.join(a.repo_root, "README.md"), encoding="utf-8").read(), "../")
    toc = "<h2>Documentation</h2><ul>" + "".join(f'<li><a href="{n}.html">{html.escape(t)}</a></li>' for n, t in index_items) + "</ul>"
    page = SHELL.format(title="Docs · Flattoo", desc="Flattoo documentation", root="../", repo=a.repo, body=toc + readme, version=html.escape(a.version))
    with open(os.path.join(a.out, "docs", "index.html"), "w", encoding="utf-8") as out:
        out.write(page)

    # landing page with a strip of screenshots the wiki has
    shots = []
    for sid, cap in [("look-home", "The Home look"), ("apps-grid", "Every app as a grid"), ("print-stencil", "Print as Stencil"),
                     ("ask-flattoo-paint", "Ask Flattoo"), ("portfolio-dialog", "Portfolio"), ("looks-gui", "Looks")]:
        if os.path.exists(os.path.join(a.wiki, "thumbs", sid + ".png")):
            shots.append(f'<figure><a href="wiki/img/{sid}.png"><img src="wiki/thumbs/{sid}.png" alt="{html.escape(cap)}" loading="lazy"></a><figcaption>{html.escape(cap)}</figcaption></figure>')
    strip = f'<div class="strip">{"".join(shots)}</div>' if shots else ""
    body = LANDING.format(repo=a.repo, strip=strip)
    page = SHELL.format(title="Flattoo — the tattoo studio laptop", desc="A tattoo studio laptop that works like a phone, prints stencils at true size, and looks after itself.", root="", repo=a.repo, body=body, version=html.escape(a.version))
    with open(os.path.join(a.out, "index.html"), "w", encoding="utf-8") as out:
        out.write(page)
    print("site:", len(docs), "docs,", len(shots), "screenshots on the front page")


if __name__ == "__main__":
    main()
