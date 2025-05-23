# Overlay interface for non-flake Nix.
final: prev:
let
  inherit (builtins) mapAttrs readFile;
  inherit (final) lib;

  # Read Elixir version manifests
  manifests = import ./lib/manifests.nix {
    inherit lib;
  };

in {
  elixir-bin = (prev.elixir-bin or { }) // import ./lib/elixir-bin.nix {
    inherit lib manifests;
    pkgs = final;
  };
}