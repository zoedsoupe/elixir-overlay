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
  mixDepsArgs ? {},
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
      fetchMixDeps (mixDepsArgs
        // {
          inherit pname version;
          src = cleanSrc;
          hash = mixDepsHash;
          mixEnv = args.mixEnv or "prod";
          mixTarget = args.mixTarget or "host";
        })
    else mixFodDeps;

  forwardedArgs = builtins.removeAttrs args [
    "toolchain"
    "mixDepsHash"
    "mixFodDeps"
    "mixNixDeps"
    "mixDepsArgs"
  ];
in
  if beamScope == null || selectedElixir == null
  then throw "beam-overlay: mkMixRelease requires a toolchain with Elixir enabled."
  else if mixRelease == null || fetchMixDeps == null
  then throw "beam-overlay: toolchain is missing its scoped mixRelease/fetchMixDeps builders."
  else if dependencyStrategies != 1
  then throw "beam-overlay: mkMixRelease requires exactly one of mixDepsHash, mixFodDeps, or non-empty mixNixDeps."
  else if mixDepsHash == null && mixDepsArgs != {}
  then throw "beam-overlay: mkMixRelease requires mixDepsHash when mixDepsArgs is set."
  else
    mixRelease (
      forwardedArgs
      // {
        inherit pname version mixNixDeps;
        src = cleanSrc;
        mixFodDeps = resolvedMixFodDeps;
      }
    )
