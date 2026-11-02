{pkgs}:
import ./release.nix {
  inherit pkgs;
  assetsDeploy = false;
}
