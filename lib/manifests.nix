{lib, ...}: let
  rawManifests = import ../manifests/stable/default.nix;
  versions = rawManifests.versions;

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
