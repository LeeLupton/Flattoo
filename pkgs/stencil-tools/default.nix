# stencil-tools: stencil-print, stencil-clean-lines, stencil-calibrate,
# stencil-queue-setup, plus desktop entries so they show up in menus and in
# "Open With".
{
  lib,
  stdenv,
  python3,
  makeWrapper,
  imagemagick,
  cups,
  zenity,
  libnotify,
  xdg-utils,
  dejavu_fonts,
  gawk,
  gnugrep,
  gnused,
  coreutils,
  runCommand,
  poppler-utils,
}:
let
  py = python3.withPackages (
    ps: with ps; [
      pillow
      numpy
    ]
  );
  runtimePath = lib.makeBinPath [
    imagemagick
    cups
    zenity
    libnotify
    xdg-utils
    gawk
    gnugrep
    gnused
    coreutils
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "stencil-tools";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ py ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/flattoo $out/share/applications

    cp lib/stencil_common.py $out/lib/flattoo/

    for tool in stencil-print stencil-clean-lines stencil-calibrate; do
      install -m755 bin/$tool $out/bin/$tool
      substituteInPlace $out/bin/$tool \
        --replace-fail '@libdir@' "$out/lib/flattoo" \
        --replace-quiet '@dejavu@' "${dejavu_fonts}"
      # The shebang goes to the python with Pillow/numpy; PATH gets magick, lp, zenity.
      sed -i "1s|.*|#!${py}/bin/python3|" $out/bin/$tool
      wrapProgram $out/bin/$tool --prefix PATH : ${runtimePath}
    done

    install -m755 bin/stencil-queue-setup $out/bin/stencil-queue-setup
    patchShebangs $out/bin/stencil-queue-setup
    wrapProgram $out/bin/stencil-queue-setup --prefix PATH : ${runtimePath}

    cp share/applications/*.desktop $out/share/applications/
    runHook postInstall
  '';

  passthru.tests.roundtrip =
    runCommand "stencil-tools-roundtrip"
      {
        nativeBuildInputs = [
          finalAttrs.finalPackage
          poppler-utils
          py
        ];
      }
      ''
        set -euo pipefail
        export HOME=$TMPDIR
        cd $TMPDIR

        # A 600x300 px design with no dpi: at 300 dpi that is 2.00 x 1.00 in.
        python3 - <<'PY'
        from PIL import Image, ImageDraw
        im = Image.new("RGB", (600, 300), "white")
        d = ImageDraw.Draw(im)
        d.rectangle([10, 10, 589, 289], outline="black", width=12)
        d.text((40, 120), "R", fill="black")
        im.save("design.png")
        # A noisy "phone photo" of a pencil sketch with a gradient background.
        import random
        sk = Image.new("L", (900, 600))
        px = sk.load()
        for y in range(600):
            for x in range(900):
                px[x, y] = max(0, min(255, int(150 + 100 * x / 900 + random.randint(-8, 8))))
        d2 = ImageDraw.Draw(sk)
        d2.line([(100, 100), (800, 500)], fill=60, width=6)
        d2.ellipse([300, 150, 600, 450], outline=70, width=5)
        sk.save("sketch.jpg", quality=85)
        PY

        stencil-print --dry-run out1.pdf design.png
        stencil-print --dry-run out2.pdf --width 4 --mirror design.png
        stencil-print --dry-run out3.pdf --page A4 --height 3 design.png
        stencil-calibrate --dry-run cal.pdf
        stencil-clean-lines --out clean.png sketch.jpg

        # Page sizes must be exact: Letter 612x792 pt, A4 595.28x841.89 pt.
        pdfinfo out1.pdf | grep -E '^Page size:\s+612 x 792 pts'
        pdfinfo out2.pdf | grep -E '^Page size:\s+612 x 792 pts'
        pdfinfo out3.pdf | grep -E '^Page size:\s+595\.?[0-9]* x 841\.?[0-9]* pts'
        pdfinfo cal.pdf  | grep -E '^Page size:\s+612 x 792 pts'

        # The embedded page image must be 1 bit per component at exactly 300 ppi.
        pdfimages -list out2.pdf | grep -E '^\s+1\s+0\s+image\s+2550\s+3300\s+gray\s+1\s+1\s+ccitt.*\s300\s+300\s'

        # Rasterize back at 300 dpi and measure the design's ink bounding box.
        pdftoppm -r 300 -gray -singlefile out2.pdf back2
        python3 - <<'PY'
        from PIL import Image, ImageOps
        im = Image.open("back2.pgm").convert("L")
        assert im.size == (2550, 3300), im.size
        bbox = ImageOps.invert(im).point(lambda v: 255 if v > 128 else 0).getbbox()
        w = bbox[2] - bbox[0]; h = bbox[3] - bbox[1]
        # 600x300 px design asked at 4.00 in wide -> 2x. The frame's outer ink
        # spans px 10..589 of 600, so 580 px -> 1160 px wide, 280 -> 560 high,
        # and its top edge sits 20 px below the 150 px (0.5 in) margin.
        assert abs(w - 1160) <= 4, w
        assert abs(h - 560) <= 4, h
        assert abs(bbox[1] - 170) <= 4, bbox
        print("ok: 4.00 x 2.00 in design placed 0.5 in from the top edge")
        clean = Image.open("clean.png")
        assert clean.mode == "1", clean.mode
        dark = clean.histogram()[0]
        assert 2000 < dark < 60000, dark   # the two strokes, no gradient, no noise
        print("ok: clean-lines produced", dark, "ink pixels")
        PY
        touch $out
      '';

  meta = {
    description = "Print tattoo stencils at true size; clean scanned sketches; calibrate the stencil printer";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "stencil-print";
  };
})
