{
  description = "Pure and reproducible Elixir overlays";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    {
      overlays.default = import ./.;
      
      # Legacy overlay name for compatibility
      overlay = self.overlays.default;
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in
      {
        packages = {
          default = pkgs.elixir-bin.latest;
          latest = pkgs.elixir-bin.latest;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir-bin.latest
          ];
        };
      }
    );
}