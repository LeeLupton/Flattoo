# Phomemo / QuYin CUPS driver: the vendor's prebuilt x86_64 raster filters
# (rastertoM08F, rastertoD480, rastertolabelmxxx) and 75 PPDs covering the
# whole catalog — M08F / M08F-WS / M08FS / M08E / "M08 pro", the TP81–TP88
# tattoo stencil printers, T08FS, and the label printers.
#
# Phomemo's own download page is JavaScript-only with no stable URL. EasyOS
# repackages the same driver as a .pet (a gzip tarball with a 32-byte md5
# footer) and mirrors it; two independent mirrors returned byte-identical
# files. The hash below pins that exact archive.
#
# `driverArchive` can be overridden with a fresher archive from phomemo.com
# (zip, tar or .pet): the install phase is layout-agnostic.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  unzip,
  file,
  gzip,
  cups,
  zlib,
  driverArchive ? null,
}:

let
  vendorArchive = fetchurl {
    urls = [
      "https://ftp.nluug.nl/os/Linux/distr/easyos/amd64/packages/pet/pet_packages-excalibur/phomemo-printer-driver-20260506.pet"
      "https://mirror.aarnet.edu.au/pub/easyos/amd64/packages/pet/pet_packages-excalibur/phomemo-printer-driver-20260506.pet"
      "https://distro.ibiblio.org/easyos/amd64/packages/pet/pet_packages-excalibur/phomemo-printer-driver-20260506.pet"
    ];
    hash = "sha256-GvqS7oUY1z21LX7TAHd6ssteJAzE2XlUUmzD8mxVch8=";
  };
in
stdenv.mkDerivation {
  pname = "phomemo-cups";
  version = "20260506";
  src = if driverArchive == null then vendorArchive else driverArchive;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
    file
    gzip
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    cups
    zlib
  ];

  sourceRoot = ".";
  dontBuild = true;
  dontConfigure = true;

  # .pet is gzip tar + 32-byte md5 footer; tar reads it as is (the footer
  # only produces a trailing-garbage warning). zip/tar come via the default
  # unpacker.
  unpackPhase = ''
    runHook preUnpack
    case "$src" in
      *.pet)
        head -c -32 "$src" | tar -xzf - 2>/dev/null || tar -xzf "$src" ;;
      *.zip)
        unzip -q "$src" ;;
      *)
        tar -xf "$src" ;;
    esac
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/cups/filter $out/share/cups/model/Phomemo

    # Nested archives (zip containing tar.gz) are common in vendor drops.
    find . -type f \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.xz' -o -name '*.zip' \) -print0 \
      | while IFS= read -r -d "" a; do
          d="$(mktemp -d ./inner.XXXX)"
          case "$a" in
            *.zip) unzip -q "$a" -d "$d" || true ;;
            *)     tar -xf "$a" -C "$d" || true ;;
          esac
        done

    n=0
    while IFS= read -r -d "" f; do
      if file -b "$f" | grep -q 'ELF 64-bit.*x86-64'; then
        install -m755 "$f" $out/lib/cups/filter/
        n=$((n+1))
      fi
    done < <(find . -type f -name 'rasterto*' -print0)
    [ "$n" -gt 0 ] || { echo "no x86_64 rasterto* filters found in the archive"; exit 1; }

    while IFS= read -r -d "" p; do
      # "M08 pro.ppd" -> "M08_pro.ppd": spaces in PPD names confuse lpinfo -m parsing.
      base="$(basename "$p" | tr ' ' '_')"
      case "$p" in
        *.gz) gunzip -c "$p" > "$out/share/cups/model/Phomemo/''${base%.gz}" ;;
        *)    install -m644 "$p" "$out/share/cups/model/Phomemo/$base" ;;
      esac
    done < <(find . -type f \( -iname '*.ppd' -o -iname '*.ppd.gz' \) -print0)
    ls $out/share/cups/model/Phomemo/*.ppd >/dev/null 2>&1 || { echo "no PPDs found in the archive"; exit 1; }

    # "/usr/lib/cups/filter/rastertoM08F" -> "rastertoM08F" (bare names resolve
    # from CUPS' own filter directory; the vendor PPDs already use them).
    sed -i -E 's#(\*cupsFilter2?:[[:space:]]*"[^"]*[[:space:]])[^" ]*/(rasterto[A-Za-z0-9_]+)#\1\2#' \
      $out/share/cups/model/Phomemo/*.ppd

    echo "filters: $(ls $out/lib/cups/filter | tr '\n' ' ')"
    echo "ppds: $(ls $out/share/cups/model/Phomemo | wc -l)"
    runHook postInstall
  '';

  meta = {
    description = "Phomemo / QuYin thermal printer CUPS driver (vendor binaries, 75 models)";
    homepage = "https://phomemo.com/pages/drivers";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
