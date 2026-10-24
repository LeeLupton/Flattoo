# Overlay: the packages Flattoo adds on top of nixpkgs.
final: prev:
let
  glibc32 = prev.pkgsi686Linux.glibc;
  pjModels = import ./brother-pj/models.nix;

  mkBrotherPj =
    model: ids:
    let
      lpr = prev.callPackage ./brother-pj/lpr.nix {
        inherit glibc32 model;
        inherit (ids) lprId lprHash;
      };
      cupswrapper = prev.callPackage ./brother-pj/cupswrapper.nix {
        inherit glibc32 model lpr;
        inherit (ids) wrapperId wrapperHash;
      };
    in
    {
      inherit lpr cupswrapper;
    };
in
{
  # Brother PocketJet 7 series (PJ-722/723/762/763/773), all five models.
  # brother-pj.pj723.lpr, brother-pj.pj723.cupswrapper, ...
  brother-pj = prev.lib.mapAttrs mkBrotherPj pjModels;

  # Convenience lists for services.printing.drivers and the /opt symlinks.
  brother-pj-cupswrappers = map (m: final.brother-pj.${m}.cupswrapper) (builtins.attrNames pjModels);
  brother-pj-lprs = map (m: final.brother-pj.${m}.lpr) (builtins.attrNames pjModels);

  # Kept for `nix build .#brother-pj723-cupswrapper` and the CI workflow.
  brother-pj723-lpr = final.brother-pj.pj723.lpr;
  brother-pj723-cupswrapper = final.brother-pj.pj723.cupswrapper;

  # Phomemo / QuYin: M08F family, TP8x stencil printers, label printers.
  phomemo-cups = prev.callPackage ./phomemo-cups { };

  # stencil-print, stencil-clean-lines, stencil-calibrate, stencil-queue-setup,
  # flattoo-session, flattoo-tablet-map
  stencil-tools = prev.callPackage ./stencil-tools { };
}
