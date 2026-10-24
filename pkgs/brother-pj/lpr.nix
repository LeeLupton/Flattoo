# Brother PocketJet 7 LPR driver: the raster converter (rastertobrpt1, 32-bit
# binary) plus the shell filter chain that feeds it. Same vendor package the
# Brother "Driver Install Tool" would install on Debian. Parameterized by
# model; see models.nix.
{
  lib,
  stdenv,
  fetchurl,
  rpmextract,
  makeWrapper,
  glibc32,
  coreutils,
  file,
  gawk,
  gnugrep,
  gnused,
  ghostscript,
  which,
  model, # "pj723"
  lprId, # "dlfp100217"
  lprHash,
}:

stdenv.mkDerivation rec {
  pname = "brother-${model}-lpr";
  version = "1.2.0-1";

  src = fetchurl {
    url = "https://download.brother.com/welcome/${lprId}/${model}lpr-${version}.i386.rpm";
    hash = lprHash;
  };

  nativeBuildInputs = [
    rpmextract
    makeWrapper
  ];

  dontUnpack = true;
  dontBuild = true;
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cd $out
    rpmextract $src

    dir=$out/opt/brother/PTouch/${model}

    # The filter derives every path from /opt/brother/PTouch/$PRINTER.
    substituteInPlace $dir/lpd/filter${model} \
      --replace-fail 'BR_PRT_PATH=/opt/brother/PTouch/$PRINTER' "BR_PRT_PATH=$dir" \
      --replace-fail 'BR_CFG_PATH=/opt/brother/PTouch/$PRINTER' "BR_CFG_PATH=$dir"

    patchShebangs $dir/lpd/filter${model} $dir/lpd/psconvertpt1 $dir/inf/setupPrintcappt1

    # Tools the shell filters call by bare name: file, gs/pdf2ps, awk, sed.
    for f in $dir/lpd/filter${model} $dir/lpd/psconvertpt1; do
      wrapProgram $f --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          file
          gawk
          gnugrep
          gnused
          ghostscript
          which
        ]
      }
    done

    # 32-bit binaries: point them at the i686 glibc loader. They link only libc.
    for b in $dir/lpd/rastertobrpt1 $out/usr/bin/brps2ps_${model} $out/usr/bin/brprintconfpt1_${model}; do
      patchelf --set-interpreter ${glibc32}/lib/ld-linux.so.2 --set-rpath ${glibc32}/lib "$b"
    done
    runHook postInstall
  '';

  passthru = {
    inherit model;
    # brprintconfpt1 has this path compiled in as a printf format string;
    # modules/printing.nix symlinks it to $out at boot.
    optPath = "/opt/brother/PTouch/${model}";
  };

  meta = {
    description = "Brother PocketJet ${lib.toUpper model} LPR driver (vendor binary)";
    homepage = "https://support.brother.com/g/b/downloadtop.aspx?c=us&lang=en&prod=${model}eus";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
