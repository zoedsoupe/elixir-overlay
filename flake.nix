{
  description = "Pure and reproducible Elixir overlays";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    {
      overlays.default = import ./.;

      overlay = self.overlays.default;
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in {
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
}
