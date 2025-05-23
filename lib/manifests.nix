{...}: let
  rawManifests = import ../manifests/stable/default.nix;
  versions = rawManifests.versions;
  latest = "1.18.4";
in {
  inherit versions latest;
}
