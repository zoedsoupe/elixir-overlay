{lib, ...}: let
  manifestDirectory = ../manifests/elixir;
  manifestFiles =
    lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".json" name)
    (builtins.readDir manifestDirectory);

  versions = lib.listToAttrs (map (file: let
    version = lib.removeSuffix ".json" file;
  in {
    name = version;
    value = builtins.fromJSON (builtins.readFile (manifestDirectory + "/${file}"));
  }) (lib.attrNames manifestFiles));

  # Automatically determine the latest stable version (excluding RC versions)
  latest = let
    stableVersions = lib.attrNames (
      lib.filterAttrs
      (version: _: !(lib.hasInfix "-rc" version))
      versions
    );
    sortedVersions =
      lib.sort
      (a: b: lib.versionOlder a b)
      stableVersions;
  in
    lib.last sortedVersions;
in {
  inherit versions latest;
}
