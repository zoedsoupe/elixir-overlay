{pkgs}: let
  beam = pkgs.beam-overlay;
  pinned = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    extraPackages = [pkgs.hello];
  };
  erlangOnly = beam.mkToolchain {
    elixir.enable = false;
    erlang-otp.version = "28";
  };
in {
  legacyAlias = beam.elixir.latest.drvPath == pkgs.elixir-bin.latest.drvPath;
  otpLatestAlias = beam."erlang-otp".latest.version == "29.1.2";
  otpMajorAlias = beam."erlang-otp"."28".version == "28.5.0.8";
  otpMinorAlias = beam."erlang-otp"."28.5".version == "28.5.0.8";
  otp25Unavailable =
    !(builtins.tryEval (builtins.deepSeq (beam.mkToolchain {
        elixir.enable = false;
        erlang-otp.version = "25";
      })
      true)).success;
  pinnedElixir = pinned.beamScope.elixir.version == "1.19.7";
  explicitOtpUsedForElixir =
    pinned.beamScope.elixir.otpVersion == pinned.beamScope.erlang.version;
  erlangOnlyHasNoElixir = pinned.beamScope.elixir != null && erlangOnly.beamScope.elixir == null;
  erlangOnlySelectsRequestedOtp =
    builtins.head (pkgs.lib.splitString "." erlangOnly.beamScope.erlang.version) == "28";
  packagesAreDerivations = pinned ? outPath && erlangOnly ? outPath;
}
