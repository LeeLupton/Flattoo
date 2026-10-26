{
  description = "Flattoo — NixOS for a tattoo studio laptop: hand sketching first, a stencil printer that prints at true size, and nothing the artist did not ask for";

  inputs = {
    # Stable channel as a tarball flake. channels.nixos.org answers with an
    # immutable releases.nixos.org URL, so the lock pins an exact release and
    # the laptop never needs the GitHub API to fetch nixpkgs.
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";

    disko = {
      url = "git+https://github.com/nix-community/disko?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      ...
    }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      overlay = import ./pkgs;

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ overlay ];
        config.allowUnfree = true; # Brother LPR binary, Microsoft core fonts
      };

      mkHost =
        modules:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit self;
          };
          modules = [
            {
              nixpkgs.overlays = [ overlay ];
              nixpkgs.config.allowUnfree = true;
            }
            disko.nixosModules.disko
          ]
          ++ modules;
        };
    in
    {
      overlays.default = overlay;
      nixosModules.flattoo = import ./modules;

      nixosConfigurations = {
        # The studio laptop. `nixos-rebuild switch --flake .#shop-laptop`
        shop-laptop = mkHost [ ./hosts/shop-laptop ];

        # Installer ISO with the flattoo-install wizard. `nix build .#iso`
        installer = mkHost [ ./hosts/installer ];
      };

      packages.${system} = {
        inherit (pkgs)
          stencil-tools
          flattoo-looks
          flattoo-copilot
          flattoo-wiki
          phomemo-cups
          brother-pj723-lpr
          brother-pj723-cupswrapper
          ;
        # All five PocketJet 7 drivers in one tree: `nix build .#brother-pj`
        brother-pj = pkgs.linkFarm "brother-pj-drivers" (
          map (d: {
            name = d.pname;
            path = d;
          }) pkgs.brother-pj-cupswrappers
        );
        iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        # Desktop screenshots for the wiki, taken in a VM: `nix build .#screenshots`
        screenshots = import ./tests/screenshots.nix { inherit pkgs self disko; };
        default = pkgs.stencil-tools;
      };

      checks.${system} = {
        stencil-tools = pkgs.stencil-tools.tests.roundtrip;
        phomemo-chain = pkgs.stencil-tools.tests.phomemoChain;
        phomemo-chain-lan = pkgs.stencil-tools.tests.phomemoChainLan;
        lan-scan = pkgs.stencil-tools.tests.lanScan;
        looks-presets = pkgs.flattoo-looks.tests.presets;
        looks-i3config = pkgs.flattoo-looks.tests.i3config;
        copilot-matcher = pkgs.flattoo-copilot.tests.matcher;
        copilot-admin = pkgs.flattoo-copilot.tests.admin;
        wiki-content = pkgs.flattoo-wiki.tests.content;
        # Every catalog entry must name a real package in the pinned nixpkgs.
        copilot-catalog = pkgs.runCommand "flattoo-copilot-catalog" {
          names = map (
            e:
            (pkgs.lib.attrByPath (pkgs.lib.splitString "." e.pkg) (throw "catalog: ${e.pkg} is not in nixpkgs")
              pkgs
            ).name
          ) (builtins.fromJSON (builtins.readFile ./pkgs/flattoo-copilot/share/flattoo/catalog.json));
        } "echo $names > $out";
        brother-pj = self.packages.${system}.brother-pj;
        phomemo-cups = pkgs.phomemo-cups;
        shop-laptop-eval = self.nixosConfigurations.shop-laptop.config.system.build.toplevel;
        # The laptop with apps the artist added through Ask Flattoo, and the
        # module's refusal of anything outside the catalog.
        copilot-apps-eval =
          let
            withApps = mkHost [
              ./hosts/shop-laptop
              {
                flattoo.apps.extra = [
                  "pinta"
                  "blender"
                  "kdePackages.kdenlive"
                ];
              }
            ];
            bad = mkHost [
              ./hosts/shop-laptop
              { flattoo.apps.extra = [ "nmap" ]; }
            ];
            rejected = lib.any (a: !a.assertion) bad.config.assertions;
          in
          assert rejected;
          withApps.config.system.build.toplevel;
        # The laptop after "Lock This Setup": captured bundle + locked mode.
        locked-eval =
          (mkHost [
            ./hosts/shop-laptop
            {
              flattoo.locked = true;
              flattoo.look.bundle = ./tests/look-bundle;
            }
          ]).config.system.build.toplevel;
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
