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
  pinnedElixir = pinned.beamScope.elixir.version == "1.19.7";
  explicitOtpUsedForElixir =
    pinned.beamScope.elixir.otpVersion == pinned.beamScope.erlang.version;
  erlangOnlyHasNoElixir = pinned.beamScope.elixir != null && erlangOnly.beamScope.elixir == null;
  erlangOnlySelectsRequestedOtp =
    builtins.head (pkgs.lib.splitString "." erlangOnly.beamScope.erlang.version) == "28";
  packagesAreDerivations = pinned ? outPath && erlangOnly ? outPath;
}
