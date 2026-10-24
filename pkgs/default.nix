# Overlay: the three packages Flattoo adds on top of nixpkgs.
final: prev: {
  # Brother PocketJet PJ-723 (the S8 tattoo stencil printer). Two vendor
  # packages, fetched from download.brother.com at build time.
  brother-pj723-lpr = prev.callPackage ./brother-pj/lpr.nix {
    glibc32 = prev.pkgsi686Linux.glibc;
  };
  brother-pj723-cupswrapper = prev.callPackage ./brother-pj/cupswrapper.nix {
    glibc32 = prev.pkgsi686Linux.glibc;
    inherit (final) brother-pj723-lpr;
  };

  # Phomemo M08F family. Vendor archive supplied by the maintainer.
  phomemo-m08f = prev.callPackage ./phomemo-m08f { };

  # stencil-print, stencil-clean-lines, stencil-calibrate, stencil-queue-setup
  stencil-tools = prev.callPackage ./stencil-tools { };
}
