final: prev: let
  inherit (final) lib;

  manifests = import ./lib/manifests.nix {
    inherit lib;
  };

  elixir-with-otp = erlang:
    import ./lib/elixir-bin.nix {
      inherit lib manifests erlang;
      pkgs = final;
    };
in {
  elixir-bin =
    (prev.elixir-bin or {})
    // import ./lib/elixir-bin.nix {
      inherit lib manifests;
      pkgs = final;
    };

  inherit elixir-with-otp;
}
