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

  elixir = elixir-with-otp null;

  mkToolchain = import ./lib/toolchain.nix {
    inherit lib;
    pkgs = final;
    defaultElixirPackages = elixir;
    elixirWithOtp = elixir-with-otp;
  };
in {
  elixir-bin =
    (prev.elixir-bin or {})
    // import ./lib/elixir-bin.nix {
      inherit lib manifests;
      pkgs = final;
    };

  inherit elixir-with-otp;

  beam-overlay = {
    inherit mkToolchain;
    inherit elixir;
  };
}
