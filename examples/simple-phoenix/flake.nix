{
  description = "Phoenix development environment using elixir-overlay";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    elixir-overlay,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [elixir-overlay.overlays.default];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir-bin."1.17.3"
            postgresql
            nodejs
            inotify-tools
            git
          ];

          shellHook = ''
            echo "🧪 Phoenix Development Environment"
            echo "Elixir: $(elixir --version | head -1)"
            echo "Node.js: $(node --version)"
            echo ""
            echo "Run 'mix phx.new my_app --live' to create a new Phoenix app"
          '';
        };
      }
    );
}
