{pkgs}: let
  beam = pkgs.beam-overlay;
  pinned = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    extraPackages = [pkgs.hello];
  };
  elixir120WithOtp29 = beam.mkToolchain {
    elixir.version = "1.20.5";
    erlang-otp.version = "29";
  };
  erlangOnly = beam.mkToolchain {
    elixir.enable = false;
    erlang-otp.version = "28";
  };
  withArchives = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    tools.phx_new.enable = true;
    tools.igniter_new.enable = true;
  };
  oldElixirWithPhoenix = beam.mkToolchain {
    elixir.version = "1.16.3";
    erlang-otp.version = "26";
    tools.phx_new.enable = true;
  };
  unknownPhoenixArchive = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    tools.phx_new = {
      enable = true;
      version = "9.9.9";
    };
  };
  withNativeTools = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    tools = {
      livebook.enable = true;
      tailwindcss = {
        enable = true;
        major = 3;
      };
      esbuild.enable = true;
    };
  };
  withTailwind4 = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    tools.tailwindcss = {
      enable = true;
      major = 4;
    };
  };
in {
  elixirBinApiRemoved = !(pkgs ? elixir-bin);
  legacyElixirUsesOverlayOtp =
    beam.elixir."1.15.8".erlang.drvPath
    == beam."erlang-otp"."26".drvPath;
  otpLatestAlias = beam."erlang-otp".latest.version == "29.1.2";
  otpMajorAlias = beam."erlang-otp"."28".version == "28.5.0.8";
  otpMinorAlias = beam."erlang-otp"."28.5".version == "28.5.0.8";
  otp25Unavailable =
    !(builtins.tryEval (builtins.deepSeq (beam.mkToolchain {
        elixir.enable = false;
        erlang-otp.version = "25";
      })
      true)).success;
  phoenixArchive = withArchives.beamScope.archives.phx_new.version == "1.8.16";
  igniterArchive = withArchives.beamScope.archives.igniter_new.version == "0.5.35";
  phoenixArchiveRequiresCompatibleElixir =
    !(builtins.tryEval (builtins.deepSeq oldElixirWithPhoenix true)).success;
  unknownPhoenixArchiveRejected =
    !(builtins.tryEval (builtins.deepSeq unknownPhoenixArchive true)).success;
  livebookSelected = withNativeTools.beamScope.tools.livebook.version == pkgs.livebook.version;
  tailwind3Selected = withNativeTools.beamScope.tools.tailwindcss.version == pkgs.tailwindcss_3.version;
  tailwind4Selected = withTailwind4.beamScope.tools.tailwindcss.version == pkgs.tailwindcss_4.version;
  esbuildSelected = withNativeTools.beamScope.tools.esbuild.version == pkgs.esbuild.version;
  pinnedElixir = pinned.beamScope.elixir.version == "1.19.7";
  explicitOtpUsedForElixir =
    pinned.beamScope.elixir.otpVersion == pinned.beamScope.erlang.version;
  elixir120SupportsOtp29 =
    elixir120WithOtp29.beamScope.elixir.version
    == "1.20.5"
    && builtins.head (pkgs.lib.splitString "." elixir120WithOtp29.beamScope.erlang.version) == "29"
    && elixir120WithOtp29.beamScope.elixir.otpVersion == elixir120WithOtp29.beamScope.erlang.version;
  erlangOnlyHasNoElixir = pinned.beamScope.elixir != null && erlangOnly.beamScope.elixir == null;
  erlangOnlySelectsRequestedOtp =
    builtins.head (pkgs.lib.splitString "." erlangOnly.beamScope.erlang.version) == "28";
  packagesAreDerivations = pinned ? outPath && erlangOnly ? outPath;
}
