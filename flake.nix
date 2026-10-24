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
          brother-pj723-lpr
          brother-pj723-cupswrapper
          ;
        iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        default = pkgs.stencil-tools;
      };

      checks.${system} = {
        stencil-tools = pkgs.stencil-tools.tests.roundtrip;
        shop-laptop-eval = self.nixosConfigurations.shop-laptop.config.system.build.toplevel;
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
