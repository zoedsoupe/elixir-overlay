{pkgs}: let
  release = import ./release.nix {inherit pkgs;};
in
  pkgs.runCommand "mix-release-check" {
    nativeBuildInputs = [release];
  } ''
    test -x ${release}/bin/mix_fixture
    RELEASE_COOKIE=mix-fixture ${release}/bin/mix_fixture eval 'IO.puts(MixFixture.message())' \
      | grep -F mix-release-eval-ok

    test ! -e ${release}/lib/mix_fixture-0.1.0/priv/static/cache_manifest.json
    touch "$out"
  ''
