{pkgs}: let
  toolchain = pkgs.beam-overlay.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
    tools.phx_new.enable = true;
    tools.igniter_new.enable = true;
  };
in
  pkgs.runCommand "beam-archives-smoke" {
    nativeBuildInputs = [toolchain];
  } ''
    export HOME="$TMPDIR/home"
    export MIX_HOME="$TMPDIR/mix"
    export HEX_HOME="$TMPDIR/hex"
    mkdir -p "$HOME" "$MIX_HOME" "$HEX_HOME"

    mix archive > "$TMPDIR/archives.txt"
    grep -F "phx_new-1.8.16.ez" "$TMPDIR/archives.txt"
    grep -F "igniter_new-0.5.35.ez" "$TMPDIR/archives.txt"
    grep -F "hex-" "$TMPDIR/archives.txt"

    mix help phx.new > /dev/null
    mix help igniter.new > /dev/null
    mix help igniter.install > /dev/null

    touch "$out"
  ''
