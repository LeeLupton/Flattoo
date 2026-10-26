# flattoo-wiki: the artist's help pages (wiki/pages/*.md + wiki/screenshots)
# rendered to static HTML with an index.json the copilot reads.
{
  lib,
  stdenv,
  python3,
  makeWrapper,
  zenity,
  xdg-utils,
  runCommand,
  flattoo-copilot,
  pages ? ../../wiki/pages,
  screenshots ? ../../wiki/screenshots,
  version ? "dev",
}:
let
  py = python3.withPackages (
    ps: with ps; [
      markdown
      pyyaml
      pillow
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "flattoo-wiki";
  inherit version;
  src = ./.;

  nativeBuildInputs = [
    makeWrapper
    py
  ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/flattoo/wiki $out/share/applications
    python3 -I build.py ${pages} ${screenshots} $out/share/flattoo/wiki --version "${version}"
    cp share/applications/*.desktop $out/share/applications/
    install -m755 bin/flattoo-wiki $out/bin/flattoo-wiki
    substituteInPlace $out/bin/flattoo-wiki --replace-fail '@wiki@' "$out/share/flattoo/wiki"
    sed -i "1s|.*|#!${py}/bin/python3|" $out/bin/flattoo-wiki
    wrapProgram $out/bin/flattoo-wiki --prefix PATH : ${
      lib.makeBinPath [
        zenity
        xdg-utils
      ]
    }
    runHook postInstall
  '';

  passthru.tests = {
    # Every page must name real copilot actions and real related pages (the
    # builder checks the latter); searches for the questions a page lists
    # must land on that page.
    content =
      runCommand "flattoo-wiki-content"
        {
          nativeBuildInputs = [
            finalAttrs.finalPackage
            flattoo-copilot
            py
          ];
        }
        ''
          export HOME=$TMPDIR
          flattoo-copilot --list-actions > actions.json
          python3 -I - ${finalAttrs.finalPackage}/share/flattoo/wiki/index.json actions.json <<'PY'
          import json, subprocess, sys
          idx = json.load(open(sys.argv[1])); actions = set(json.load(open(sys.argv[2])))
          pages = idx["pages"]
          assert len(pages) >= 20, len(pages)
          bad = 0
          for p in pages:
              for a in p["actions"]:
                  if a not in actions:
                      print("unknown action", p["id"], a); bad += 1
              for q in p["questions"]:
                  out = subprocess.run(["flattoo-wiki", "search", "--json", q], capture_output=True, text=True).stdout
                  hits = json.loads(out)
                  if not hits or hits[0]["id"] != p["id"]:
                      print(f"question {q!r} on {p['id']} ranks {[h['id'] for h in hits[:3]]}"); bad += 1
          print(len(pages), "pages;", "pending screenshots:", idx["missing_screenshots"])
          sys.exit(1 if bad else 0)
          PY
          # Ask Flattoo with the wiki in reach: "how do I…" opens the right page.
          export XDG_DATA_DIRS=${finalAttrs.finalPackage}/share XDG_STATE_HOME=$TMPDIR/state
          check() { res=$(flattoo-copilot --dry-run --no-gui "$1"); echo "$res" | grep -q "\"action\": \"$2\"" && echo "$res" | grep -q "\"page\": \"$3\"" || { echo "FAIL $1 -> $res"; exit 1; }; echo "ok   $1 -> $3"; }
          check "how do I scan a sketch" learn sketch-to-stencil
          check "how do I get photos from my phone" learn phone-photos
          check "what is the lock screen password" learn lock-screen
          check "explain lock this setup" learn lock-setup
          check "where did my file go" learn files
          check "is it safe on public wifi" learn safety
          check "what are the keyboard shortcuts" learn shortcuts
          check "how do I go back to how it was" learn updates
          # chores still win over the wiki when they are the better answer
          act() { res=$(flattoo-copilot --dry-run --no-gui "$1"); echo "$res" | grep -q "\"action\": \"$2\"" || { echo "FAIL $1 -> $res"; exit 1; }; echo "ok   $1 -> $2"; }
          act "the printer isn't working" printer-fix
          act "install pinta" install
          act "dark mode" look
          act "help" help
          touch $out
        '';
  };

  meta = {
    description = "Flattoo help: plain-English pages with screenshots, indexed for Ask Flattoo";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "flattoo-wiki";
  };
})
