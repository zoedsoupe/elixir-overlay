final: prev: let
  inherit (final) lib;

  manifests = import ./lib/manifests.nix {
    inherit lib;
  };

  elixir-with-otp = erlang:
    import ./lib/elixir-bin.nix {
      inherit lib manifests erlang;
      pkgs = final;
      erlangOtpPackages = erlangOtp.packages;
    };

  elixir = elixir-with-otp null;

  erlangOtp = import ./lib/erlang-otp.nix {
    inherit lib;
    pkgs = final;
  };

  mkToolchain = import ./lib/toolchain.nix {
    inherit lib;
    pkgs = final;
    defaultElixirPackages = elixir;
    elixirWithOtp = elixir-with-otp;
    inherit erlangOtp;
  };

  mkMixRelease = import ./lib/mix-release.nix {
    inherit lib;
    pkgs = final;
  };

  mkPhoenixRelease = import ./lib/phoenix.nix {
    inherit lib mkMixRelease;
    pkgs = final;
  };
in {
  elixir-bin =
    (prev.elixir-bin or {})
    // import ./lib/elixir-bin.nix {
      inherit lib manifests;
      pkgs = final;
      erlangOtpPackages = erlangOtp.packages;
    };

  inherit elixir-with-otp;

  beam-overlay = {
    inherit mkToolchain mkMixRelease mkPhoenixRelease;
    inherit elixir;
    "erlang-otp" = erlangOtp.packages;
  };
}
