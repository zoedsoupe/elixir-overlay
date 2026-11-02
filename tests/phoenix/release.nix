{
  pkgs,
  assetsDeploy ? true,
}: let
  toolchain = pkgs.beam-overlay.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
  };
in
  pkgs.beam-overlay.mkPhoenixRelease {
    inherit toolchain;
    pname = "phoenix-fixture";
    version = "0.1.0";
    src = ./fixture;
    mixDepsHash = pkgs.lib.fakeHash;
    inherit assetsDeploy;
    tailwindcss =
      if assetsDeploy
      then pkgs.tailwindcss_4
      else null;
    esbuild =
      if assetsDeploy
      then pkgs.esbuild
      else null;
  }
