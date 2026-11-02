{pkgs}: let
  beam = pkgs.beam-overlay;
  toolchain = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
  };
  base = {
    inherit toolchain;
    pname = "mix-fixture";
    version = "0.1.0";
    src = ./fixture;
  };
  byHash = beam.mkMixRelease (base // {mixDepsHash = pkgs.lib.fakeHash;});
  withDepsArgs = beam.mkMixRelease (base
    // {
      mixDepsHash = pkgs.lib.fakeHash;
      mixDepsArgs = {
        env.MDEX_NATIVE_BUILD = "1";
        postInstall = "cargo vendor --locked";
      };
    });
  directFodWithDepsArgs = beam.mkMixRelease (base
    // {
      mixFodDeps = pkgs.runCommand "empty-mix-deps" {} "mkdir -p $out";
      mixDepsArgs.env.MDEX_NATIVE_BUILD = "1";
    });
  erlangOnly = beam.mkToolchain {
    elixir.enable = false;
    erlang-otp.version = "28";
  };
  noElixir = beam.mkMixRelease (base
    // {
      toolchain = erlangOnly;
      mixDepsHash = pkgs.lib.fakeHash;
    });
in {
  hashStrategyBuilds = byHash.drvPath != "";
  noPhoenixAssetHooks =
    !(pkgs.lib.hasInfix "assets.deploy" (byHash.preInstall or ""))
    && !(pkgs.lib.hasInfix "Tailwind.bin_path()" (byHash.postConfigure or ""))
    && !(pkgs.lib.hasInfix "Esbuild.bin_path()" (byHash.postConfigure or ""));
  mixDepsArgsAreForwarded =
    withDepsArgs.mixFodDeps.MDEX_NATIVE_BUILD
    == "1"
    && pkgs.lib.hasInfix "cargo vendor --locked" withDepsArgs.mixFodDeps.postInstall;
  mixDepsArgsRequireHash =
    !(builtins.tryEval (builtins.deepSeq directFodWithDepsArgs.drvPath true)).success;
  elixirIsRequired =
    !(builtins.tryEval (builtins.deepSeq noElixir.drvPath true)).success;
}
