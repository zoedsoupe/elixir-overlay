{
  pkgs,
  pname,
  version,
  src,
  mixDepsHash,
}: let
  beam = pkgs.beam-overlay;
  toolchain = beam.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
  };

  mixFodDeps = toolchain.beamScope.fetchMixDeps {
    inherit pname version src;
    hash = mixDepsHash;

    preInstall = ''
      export CARGO_HOME="$TEMPDIR/cargo-home"
    '';

    postInstall = ''
      crate_dir="$out/mdex_native/native/mdex_native_nif"
      test -f "$crate_dir/Cargo.toml"
      mkdir -p "$crate_dir/.cargo"
      (
        cd "$crate_dir"
        ${pkgs.cargo}/bin/cargo vendor --locked vendor > .cargo/config.toml
      )
    '';
  };
in
  beam.mkMixRelease {
    inherit toolchain pname version src mixFodDeps;

    env.MDEX_NATIVE_BUILD = "1";
    nativeBuildInputs = [pkgs.cargo pkgs.rustc];
    preConfigure = ''
      export CARGO_HOME="$TMPDIR/cargo-home"
    '';
  }
