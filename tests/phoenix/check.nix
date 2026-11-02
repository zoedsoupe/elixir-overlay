{pkgs}: let
  release = import ./release.nix {inherit pkgs;};
  releaseWithoutAssets = import ./no-assets.nix {inherit pkgs;};
in
  pkgs.runCommand "phoenix-release-check" {
    nativeBuildInputs = [release releaseWithoutAssets];
  } ''
    test -x ${release}/bin/phoenix_fixture
    export RELEASE_COOKIE=phoenix-fixture-check-cookie
    ${release}/bin/phoenix_fixture eval 'IO.puts("phoenix-release-eval-ok")' \
      | grep -F phoenix-release-eval-ok

    static_dir="${release}/lib/phoenix_fixture-0.1.0/priv/static"
    test -f "$static_dir/cache_manifest.json"
    find "$static_dir/assets" -name 'app-*.css' -type f | grep -q .
    find "$static_dir/assets" -name 'app-*.js' -type f | grep -q .

    test ! -e ${releaseWithoutAssets}/lib/phoenix_fixture-0.1.0/priv/static/cache_manifest.json
    touch "$out"
  ''
