{pkgs}: let
  toolchain = pkgs.beam-overlay.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
  };
in
  pkgs.beam-overlay.mkMixRelease {
    inherit toolchain;
    pname = "mix-fixture";
    version = "0.1.0";
    src = ./fixture;
    mixFodDeps = pkgs.runCommand "mix-fixture-empty-deps" {} "mkdir -p $out";
  }
