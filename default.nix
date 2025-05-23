final: prev: let
  inherit (final) lib;

  manifests = import ./lib/manifests.nix {
    inherit lib;
  };
in {
  elixir-bin =
    (prev.elixir-bin or {})
    // import ./lib/elixir-bin.nix {
      inherit lib manifests;
      pkgs = final;
    };
}
