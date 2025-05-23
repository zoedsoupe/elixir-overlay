{pkgs ? import <nixpkgs> {overlays = [(import ../../.)];}}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    elixir-bin.latest
    postgresql
    nodejs
    inotify-tools
  ];

  shellHook = ''
    echo "🧪 Elixir Development Environment"
    echo "Elixir version: $(elixir --version | head -1)"
    echo "Available commands:"
    echo "  mix new my_app                 # Create new Elixir project"
    echo "  mix phx.new my_web_app --live  # Create new Phoenix LiveView app"
    echo ""
  '';
}
