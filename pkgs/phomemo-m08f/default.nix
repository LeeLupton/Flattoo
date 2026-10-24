# Phomemo M08F family (M08F, M08F Plus, M08F Pro, and the rebrands that ship
# the same firmware). Phomemo publishes a Linux driver package containing
# prebuilt x86_64 CUPS raster filters (rastertoM08F and friends) and PPDs, but
# only behind a JavaScript download page with no stable URL. So:
#
#   1. Download the Linux driver from https://phomemo.com/pages/drivers
#      (or the EasyOS repack: phomemo-printer-driver-*.pet is a tar.xz).
#   2. Put it in the repo as vendor/phomemo-linux-driver.<zip|tar.gz|tar.xz>
#   3. hosts/shop-laptop/default.nix:
#        flattoo.stencil.phomemo.enable = true;
#        flattoo.stencil.phomemo.driverArchive = ../../vendor/phomemo-linux-driver.zip;
#
# The build is layout-agnostic: it takes every x86_64 rasterto* filter and
# every PPD it finds, and rewrites the PPDs' *cupsFilter lines to bare filter
# names so CUPS resolves them from its own filter directory.
{
  lib,
  stdenv,
  autoPatchelfHook,
  unzip,
  file,
  gzip,
  cups,
  zlib,
  libpng,
  libjpeg,
  src ? null,
}:

stdenv.mkDerivation {
  pname = "phomemo-m08f-cups";
  version = "vendor";
  src =
    if src == null then
      throw ''
        phomemo-m08f: no driver archive. Set flattoo.stencil.phomemo.driverArchive
        to Phomemo's Linux driver file (see pkgs/phomemo-m08f/default.nix).
      ''
    else
      src;

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
    libpng
    libjpeg
  ];

  sourceRoot = ".";
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/cups/filter $out/share/cups/model/Phomemo

    # Nested archives (zip containing tar.gz) are common in vendor drops.
    find . -type f \( -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.xz' -o -name '*.pet' -o -name '*.zip' \) -print0 \
      | while IFS= read -r -d "" a; do
          d="$(mktemp -d ./inner.XXXX)"
          case "$a" in
            *.zip) unzip -q "$a" -d "$d" || true ;;
            *.pet) head -c -32 "$a" | tar -xJf - -C "$d" 2>/dev/null || tar -xf "$a" -C "$d" || true ;;
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
      case "$p" in
        *.gz) gunzip -c "$p" > "$out/share/cups/model/Phomemo/$(basename "''${p%.gz}")" ;;
        *)    install -m644 "$p" $out/share/cups/model/Phomemo/ ;;
      esac
    done < <(find . -type f \( -iname '*.ppd' -o -iname '*.ppd.gz' \) -print0)
    ls $out/share/cups/model/Phomemo/*.ppd >/dev/null 2>&1 || { echo "no PPDs found in the archive"; exit 1; }

    # "/usr/lib/cups/filter/rastertoM08F" -> "rastertoM08F"
    sed -i -E 's#(\*cupsFilter2?:[[:space:]]*"[^"]*[[:space:]])[^" ]*/(rasterto[A-Za-z0-9_]+)#\1\2#' \
      $out/share/cups/model/Phomemo/*.ppd

    echo "filters:"; ls $out/lib/cups/filter
    echo "ppds:";    ls $out/share/cups/model/Phomemo
    runHook postInstall
  '';

  meta = {
    description = "Phomemo M08F-family CUPS driver (vendor binaries)";
    homepage = "https://phomemo.com/pages/drivers";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
