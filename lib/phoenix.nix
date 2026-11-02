{
  lib,
  pkgs,
}: {
  toolchain,
  pname,
  version,
  src,
  mixDepsHash ? null,
  mixFodDeps ? null,
  mixNixDeps ? {},
  assetsDeploy ? true,
  tailwindcss ? pkgs.tailwindcss_4,
  esbuild ? pkgs.esbuild,
  ...
} @ args: let
  beamScope = toolchain.beamScope or null;
  selectedElixir =
    if beamScope == null
    then null
    else beamScope.elixir or null;
  mixRelease =
    if beamScope == null
    then null
    else beamScope.mixRelease or null;
  fetchMixDeps =
    if beamScope == null
    then null
    else beamScope.fetchMixDeps or null;

  cleanSrc = pkgs.lib.cleanSourceWith {
    inherit src;
    filter = path: _type: let
      pathString = toString path;
      sourcePath = toString src;
      isRootEntry = builtins.dirOf pathString == sourcePath;
      name = builtins.baseNameOf pathString;
    in
      lib.cleanSourceFilter path _type
      && !(isRootEntry && builtins.elem name ["_build" "deps" "_checkouts" "cover" ".elixir_ls"])
      && !(name == "node_modules" && _type == "directory");
  };

  dependencyStrategies =
    (
      if mixDepsHash != null
      then 1
      else 0
    )
    + (
      if mixFodDeps != null
      then 1
      else 0
    )
    + (
      if mixNixDeps != {}
      then 1
      else 0
    );

  resolvedMixFodDeps =
    if mixDepsHash != null
    then
      fetchMixDeps {
        inherit pname version;
        src = cleanSrc;
        hash = mixDepsHash;
        mixEnv = args.mixEnv or "prod";
        mixTarget = args.mixTarget or "host";
      }
    else mixFodDeps;

  queryBinPath = module: ''
    ${toolchain}/bin/mix run \
      --no-compile \
      --no-deps-check \
      --no-start \
      -e 'IO.write(${module}.bin_path())'
  '';

  linkTailwind = lib.optionalString (assetsDeploy && tailwindcss != null) ''
    tailwind_bin_path="$(${queryBinPath "Tailwind"})"
    mkdir -p "$(dirname "$tailwind_bin_path")"
    ln -sfn ${tailwindcss}/bin/tailwindcss "$tailwind_bin_path"
  '';

  linkEsbuild = lib.optionalString (assetsDeploy && esbuild != null) ''
    esbuild_bin_path="$(${queryBinPath "Esbuild"})"
    mkdir -p "$(dirname "$esbuild_bin_path")"
    ln -sfn ${esbuild}/bin/esbuild "$esbuild_bin_path"
  '';

  generatedPostConfigure = linkTailwind + linkEsbuild;
  generatedPreInstall = lib.optionalString assetsDeploy ''
    ${toolchain}/bin/mix assets.deploy --no-deps-check
  '';

  appendHook = name: generated: let
    existing = args.${name} or "";
  in
    lib.concatStringsSep "\n" (builtins.filter (hook: hook != "") [existing generated]);

  forwardedArgs = builtins.removeAttrs args [
    "toolchain"
    "mixDepsHash"
    "mixFodDeps"
    "mixNixDeps"
    "assetsDeploy"
    "tailwindcss"
    "esbuild"
  ];
in
  if beamScope == null || selectedElixir == null
  then throw "beam-overlay: mkPhoenixRelease requires a toolchain with Elixir enabled."
  else if mixRelease == null || fetchMixDeps == null
  then throw "beam-overlay: toolchain is missing its scoped mixRelease/fetchMixDeps builders."
  else if dependencyStrategies != 1
  then throw "beam-overlay: mkPhoenixRelease requires exactly one of mixDepsHash, mixFodDeps, or non-empty mixNixDeps."
  else
    mixRelease (
      forwardedArgs
      // {
        inherit pname version mixNixDeps;
        src = cleanSrc;
        mixFodDeps = resolvedMixFodDeps;
        postConfigure = appendHook "postConfigure" generatedPostConfigure;
        preInstall = appendHook "preInstall" generatedPreInstall;
      }
    )
