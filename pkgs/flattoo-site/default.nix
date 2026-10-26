# The GitHub Pages site: landing page (download, what it is), the wiki, the
# docs rendered. `nix build .#site` -> result/ is what Pages serves.
{
  lib,
  runCommand,
  python3,
  flattoo-wiki,
  repoRoot ? ../..,
  version ? "dev",
  repo ? "LeeLupton/Flattoo",
}:
let
  py = python3.withPackages (ps: [ ps.markdown ]);
in
runCommand "flattoo-site"
  {
    nativeBuildInputs = [ py ];
    meta.description = "Flattoo website: download, docs, wiki";
  }
  ''
    python3 -I ${./build.py} ${repoRoot} ${flattoo-wiki}/share/flattoo/wiki $out --version "${version}" --repo "${repo}"
    test -f $out/index.html && test -f $out/wiki/index.html && test -f $out/docs/install.html
  ''
