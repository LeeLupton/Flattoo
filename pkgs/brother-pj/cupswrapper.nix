# Brother PJ-723 CUPS wrapper: the PPD plus the filter that turns CUPS
# options into Brother's rc file and hands PostScript to the LPR filter.
#
# Brother's installer *generates* the CUPS filter at install time from a
# heredoc in cupswrapperpj723. We run that same heredoc at build time, then
# rewrite its hard-coded /opt and /usr paths to store paths.
{
  lib,
  stdenv,
  fetchurl,
  rpmextract,
  makeWrapper,
  bash,
  glibc32,
  coreutils,
  gnugrep,
  gnused,
  psutils,
  brother-pj723-lpr,
}:

stdenv.mkDerivation rec {
  pname = "brother-pj723-cupswrapper";
  version = "1.2.0-1";

  src = fetchurl {
    url = "https://download.brother.com/welcome/dlfp100218/pj723cupswrapper-${version}.i386.rpm";
    hash = "sha256-LxTcsGzyLh6CPx9l/MhCj8MNRKY9JjNczmXYxqcf9qE=";
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

    dir=$out/opt/brother/PTouch/pj723/cupswrapper
    lpr=${brother-pj723-lpr}/opt/brother/PTouch/pj723

    # --- generate brother_lpdwrapper_pj723 exactly as Brother's script does
    gen=$(mktemp)
    {
      echo 'printer_model=pj723'
      echo 'device_model=PTouch'
      echo "tmp_filter=$dir/brother_lpdwrapper_pj723"
      sed -n '/^cat <<!ENDOFWFILTER! >\$tmp_filter$/,/^!ENDOFWFILTER!$/p' $dir/cupswrapperpj723
    } > $gen
    ${bash}/bin/bash $gen
    rm $gen
    test -s $dir/brother_lpdwrapper_pj723
    chmod 755 $dir/brother_lpdwrapper_pj723

    # --- rewrite paths baked into the generated filter
    # (cupswrapper paths first via a placeholder, so the lpr substitution
    # cannot match inside the already-rewritten store path)
    sed -i \
      -e "s|/opt/brother/PTouch/pj723/cupswrapper|@CUPSWRAPPER@|g" \
      -e "s|/opt/brother/PTouch/pj723|$lpr|g" \
      -e "s|@CUPSWRAPPER@|$dir|g" \
      -e "s|/usr/share/cups/model/Brother|$out/share/cups/model/Brother|g" \
      -e "s|/usr/bin/psnup|${psutils}/bin/psnup|g" \
      $dir/brother_lpdwrapper_pj723
    grep -q "$lpr/lpd/filterpj723" $dir/brother_lpdwrapper_pj723
    grep -q "$dir/brcupsconfpt1" $dir/brother_lpdwrapper_pj723
    ! grep -q "$out/nix/store" $dir/brother_lpdwrapper_pj723

    patchShebangs $dir/brother_lpdwrapper_pj723
    # brcupsconfpt1 shells out to brprintconfpt1_pj723 (LPR package) by bare
    # name to write each option into the rc file, so that must be on PATH.
    wrapProgram $dir/brother_lpdwrapper_pj723 \
      --prefix PATH : ${brother-pj723-lpr}/usr/bin \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          gnugrep
          gnused
          psutils
        ]
      }

    # brcupsconfpt1 (option translator) is a 32-bit binary linking only libc.
    patchelf --set-interpreter ${glibc32}/lib/ld-linux.so.2 --set-rpath ${glibc32}/lib $dir/brcupsconfpt1

    # --- what CUPS sees
    mkdir -p $out/lib/cups/filter $out/share/cups/model/Brother
    ln -s $dir/brother_lpdwrapper_pj723 $out/lib/cups/filter/brother_lpdwrapper_pj723
    cp $dir/brother_pj723_printer_en.ppd $out/share/cups/model/Brother/

    # The installer script itself is not needed on NixOS.
    rm $dir/cupswrapperpj723
    runHook postInstall
  '';

  meta = {
    description = "Brother PocketJet PJ-723 CUPS wrapper driver";
    homepage = "https://support.brother.com/g/b/downloadtop.aspx?c=us&lang=en&prod=pj723eus";
    license = lib.licenses.gpl2Plus; # the wrapper scripts; brcupsconfpt1 is unfree
    platforms = [ "x86_64-linux" ];
  };
}
