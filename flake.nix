{
  description = "Pure and reproducible BEAM packages and runtime helpers for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05-small";

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    perSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in {
        checks = nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          beam-apps = import ./tests/beam-apps.nix {
            inherit pkgs;
            beamModule = self.nixosModules.beam;
          };
          beam-image = import ./tests/beam-image.nix {
            inherit pkgs;
            mkBeamImage = self.lib.mkBeamImage;
          };
        };

        packages =
          {
            default = pkgs.elixir-bin.latest;
            latest = pkgs.elixir-bin.latest;
          }
          // (nixpkgs.lib.mapAttrs' (version: pkg: {
              name = "elixir_${builtins.replaceStrings ["."] ["_"] version}";
              value = pkg;
            })
            pkgs.elixir-bin);

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir-bin.latest
            alejandra
          ];
        };
      }
    );
  in {
    overlays.default = import ./.;

    overlay = self.overlays.default;

    nixosModules = {
      beam = import ./modules/beam-apps.nix;
      default = self.nixosModules.beam;
    };

    lib.mkBeamImage = import ./lib/beam-image.nix;

    checks = builtins.mapAttrs (_: systemOutputs: systemOutputs.checks) perSystem;
    packages = builtins.mapAttrs (_: systemOutputs: systemOutputs.packages) perSystem;
    devShells = builtins.mapAttrs (_: systemOutputs: systemOutputs.devShells) perSystem;
  };
}
