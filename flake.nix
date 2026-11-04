{
  description = "Pure and reproducible BEAM packages and runtime helpers for Nix";

  nixConfig = {
    extra-substituters = ["https://elixir-overlay.cachix.org"];
    extra-trusted-public-keys = [
      "elixir-overlay.cachix.org-1:03zcUxISSuNn2vnKPfUJFinDGU5vzhyc+cPbB7u77xA="
    ];
  };

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
        otpSmoke =
          (import ./tests/otp-compat.nix {
            inherit (pkgs) lib;
            inherit pkgs;
          }).smoke;
        otpSmokeChecks =
          nixpkgs.lib.mapAttrs' (version: drv: {
            name = "otp-${builtins.replaceStrings ["."] ["_"] version}-smoke";
            value = drv;
          })
          otpSmoke;
      in {
        checks =
          nixpkgs.lib.optionalAttrs pkgs.stdenv.isLinux (
            {
              archives = import ./tests/archives.nix {inherit pkgs;};
              beam-apps = import ./tests/beam-apps.nix {
                inherit pkgs;
                beamModule = self.nixosModules.beam-apps;
              };
              beam-containers = import ./tests/beam-containers.nix {
                inherit pkgs;
                beamContainersModule = self.nixosModules.beam-containers;
              };
              beam-image = import ./tests/beam-image.nix {
                inherit pkgs;
                mkBeamImage = self.lib.mkBeamImage;
              };
              mix-release = import ./tests/mix/check.nix {inherit pkgs;};
              phoenix-release = import ./tests/phoenix/check.nix {inherit pkgs;};
            }
            // otpSmokeChecks
          )
          // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") otpSmokeChecks;

        packages = let
          elixirPackages = pkgs.beam-overlay.elixir;
          versions = nixpkgs.lib.filterAttrs (version: _: version != "latest") elixirPackages;
        in
          {
            default = elixirPackages.latest;
            latest = elixirPackages.latest;
          }
          // (nixpkgs.lib.mapAttrs' (version: pkg: {
              name = "elixir_${builtins.replaceStrings ["."] ["_"] version}";
              value = pkg;
            })
            versions);

        devShells.default = pkgs.mkShell {
          packages = [
            (pkgs.beam-overlay.mkToolchain {})
            pkgs.alejandra
          ];
        };
      }
    );
  in {
    overlays.default = import ./.;

    overlay = self.overlays.default;

    nixosModules = {
      beam-apps = import ./modules/beam-apps.nix;
      beam-containers = import ./modules/beam-containers.nix;
      beam = {
        imports = [
          ./modules/beam-apps.nix
          ./modules/beam-containers.nix
        ];
      };
      default = self.nixosModules.beam;
    };

    lib.mkBeamImage = import ./lib/beam-image.nix;

    checks = builtins.mapAttrs (_: systemOutputs: systemOutputs.checks) perSystem;
    packages = builtins.mapAttrs (_: systemOutputs: systemOutputs.packages) perSystem;
    devShells = builtins.mapAttrs (_: systemOutputs: systemOutputs.devShells) perSystem;
  };
}
