# Brother PocketJet 7 CUPS wrapper: the PPD plus the filter that turns CUPS
# options into Brother's rc file and hands PostScript to the LPR filter.
#
# Brother's installer *generates* the CUPS filter at install time from a
# heredoc in cupswrapper<model>. We run that same heredoc at build time, then
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
  lpr, # the matching brother-<model>-lpr
  model,
  wrapperId,
  wrapperHash,
}:

stdenv.mkDerivation rec {
  pname = "brother-${model}-cupswrapper";
  version = "1.2.0-1";

  src = fetchurl {
    url = "https://download.brother.com/welcome/${wrapperId}/${model}cupswrapper-${version}.i386.rpm";
    hash = wrapperHash;
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

    dir=$out/opt/brother/PTouch/${model}/cupswrapper
    lprdir=${lpr}/opt/brother/PTouch/${model}
    filter=$dir/brother_lpdwrapper_${model}

    # --- generate brother_lpdwrapper_<model> exactly as Brother's script does
    gen=$(mktemp)
    {
      echo 'printer_model=${model}'
      echo 'device_model=PTouch'
      echo "tmp_filter=$filter"
      sed -n '/^cat <<!ENDOFWFILTER! >\$tmp_filter$/,/^!ENDOFWFILTER!$/p' $dir/cupswrapper${model}
    } > $gen
    ${bash}/bin/bash $gen
    rm $gen
    test -s $filter
    chmod 755 $filter

    # --- rewrite paths baked into the generated filter
    # (cupswrapper paths first via a placeholder, so the lpr substitution
    # cannot match inside the already-rewritten store path)
    sed -i \
      -e "s|/opt/brother/PTouch/${model}/cupswrapper|@CUPSWRAPPER@|g" \
      -e "s|/opt/brother/PTouch/${model}|$lprdir|g" \
      -e "s|@CUPSWRAPPER@|$dir|g" \
      -e "s|/usr/share/cups/model/Brother|$out/share/cups/model/Brother|g" \
      -e "s|/usr/bin/psnup|${psutils}/bin/psnup|g" \
      $filter
    grep -q "$lprdir/lpd/filter${model}" $filter
    grep -q "$dir/brcupsconfpt1" $filter
    ! grep -q "$out/nix/store" $filter

    patchShebangs $filter
    # brcupsconfpt1 shells out to brprintconfpt1_<model> (LPR package) by bare
    # name to write each option into the rc file, so that must be on PATH.
    wrapProgram $filter \
      --prefix PATH : ${lpr}/usr/bin \
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
    ln -s $filter $out/lib/cups/filter/brother_lpdwrapper_${model}
    cp $dir/brother_${model}_printer_en.ppd $out/share/cups/model/Brother/

    # The installer script itself is not needed on NixOS.
    rm $dir/cupswrapper${model}
    runHook postInstall
  '';

  passthru = {
    inherit model lpr;
  };

  meta = {
    description = "Brother PocketJet ${lib.toUpper model} CUPS wrapper driver";
    homepage = "https://support.brother.com/g/b/downloadtop.aspx?c=us&lang=en&prod=${model}eus";
    license = lib.licenses.gpl2Plus; # the wrapper scripts; brcupsconfpt1 is unfree
    platforms = [ "x86_64-linux" ];
  };
}
