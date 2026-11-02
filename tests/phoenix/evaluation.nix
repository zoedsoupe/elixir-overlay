{pkgs}: let
  beam = pkgs.beam-overlay;
  toolchain = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
  };
  base = {
    inherit toolchain;
    pname = "phoenix-fixture";
    version = "0.1.0";
    src = ./fixture;
  };
  byHash = beam.mkPhoenixRelease (base // {mixDepsHash = pkgs.lib.fakeHash;});
  directFod = beam.mkPhoenixRelease (base
    // {
      mixFodDeps = pkgs.runCommand "empty-mix-deps" {} "mkdir -p $out";
    });
  byNixDeps = beam.mkPhoenixRelease (base
    // {
      mixNixDeps = {example = pkgs.hello;};
    });
  withHooks = beam.mkPhoenixRelease (base
    // {
      mixDepsHash = pkgs.lib.fakeHash;
      preInstall = "touch user-pre-install-hook";
      postConfigure = "touch user-post-configure-hook";
    });
  withoutAssets = beam.mkPhoenixRelease (base
    // {
      mixDepsHash = pkgs.lib.fakeHash;
      assetsDeploy = false;
      tailwindcss = null;
      esbuild = null;
    });
  withDepsArgs = beam.mkPhoenixRelease (base
    // {
      mixDepsHash = pkgs.lib.fakeHash;
      mixDepsArgs.env.MDEX_NATIVE_BUILD = "1";
    });
  noStrategy = beam.mkPhoenixRelease base;
  cleanedEntries = builtins.readDir byHash.src;
  twoStrategies = beam.mkPhoenixRelease (base
    // {
      mixDepsHash = pkgs.lib.fakeHash;
      mixNixDeps = {example = pkgs.hello;};
    });
  erlangOnly = beam.mkToolchain {
    elixir.enable = false;
    erlang-otp.version = "28";
  };
  noElixir = beam.mkPhoenixRelease (base
    // {
      toolchain = erlangOnly;
      mixDepsHash = pkgs.lib.fakeHash;
    });
in {
  scopeCarriesBuilders =
    toolchain.beamScope.mixRelease
    != null
    && toolchain.beamScope.fetchMixDeps != null;
  hashStrategyBuilds = byHash.drvPath != "";
  directFodStrategyBuilds = directFod.drvPath != "";
  nixDepsStrategyBuilds = byNixDeps.drvPath != "";
  standardMixBuildPathsAreFiltered =
    !(cleanedEntries ? _build)
    && !(cleanedEntries ? deps)
    && !(cleanedEntries ? _checkouts)
    && !(cleanedEntries ? cover);
  userHooksArePreserved =
    pkgs.lib.hasInfix "user-pre-install-hook" withHooks.preInstall
    && pkgs.lib.hasInfix "user-post-configure-hook" withHooks.postConfigure;
  assetHooksAreAdded =
    pkgs.lib.hasInfix "assets.deploy --no-deps-check" withHooks.preInstall
    && pkgs.lib.hasInfix "Tailwind.bin_path()" withHooks.postConfigure
    && pkgs.lib.hasInfix "Esbuild.bin_path()" withHooks.postConfigure;
  assetHooksCanBeDisabled =
    !(pkgs.lib.hasInfix "assets.deploy" withoutAssets.preInstall)
    && !(pkgs.lib.hasInfix "Tailwind.bin_path()" withoutAssets.postConfigure)
    && !(pkgs.lib.hasInfix "Esbuild.bin_path()" withoutAssets.postConfigure);
  mixDepsArgsAreForwarded = withDepsArgs.mixFodDeps.MDEX_NATIVE_BUILD == "1";
  noStrategyIsRejected =
    !(builtins.tryEval (builtins.deepSeq noStrategy.drvPath true)).success;
  multipleStrategiesAreRejected =
    !(builtins.tryEval (builtins.deepSeq twoStrategies.drvPath true)).success;
  elixirIsRequired =
    !(builtins.tryEval (builtins.deepSeq noElixir.drvPath true)).success;
}
