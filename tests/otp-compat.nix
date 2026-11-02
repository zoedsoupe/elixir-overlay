{
  lib,
  pkgs,
}: let
  erlangOtp = import ../lib/erlang-otp.nix {inherit lib pkgs;};
  endpointVersions = [
    "26.0"
    "26.2.5.21"
    "27.0"
    "27.3.4.19"
    "28.0"
    "28.5.0.8"
    "29.0"
    "29.1.2"
  ];
  packages = lib.genAttrs endpointVersions (version:
    erlangOtp.build {
      inherit version;
      inherit (erlangOtp.versions.${version}) hash;
    });

  smoke = lib.mapAttrs (version: erlang:
    pkgs.runCommand "erlang-otp-${version}-smoke" {
      nativeBuildInputs = [erlang];
    } ''
      erl -noshell -eval '
        Pid = spawn(fun() -> ok end),
        true = is_pid(Pid),
        Bytes = crypto:strong_rand_bytes(32),
        32 = byte_size(Bytes),
        io:format("otp-runtime-smoke-ok~n"),
        halt(0).
      '
      mkdir -p "$out"
      touch "$out/smoke-passed"
    '')
  packages;
in {
  inherit packages smoke;
  aliases = {
    latest = erlangOtp.packages.latest.version;
    otp26 = erlangOtp.packages."26".version;
    otp27 = erlangOtp.packages."27".version;
    otp28 = erlangOtp.packages."28".version;
    otp29 = erlangOtp.packages."29".version;
  };
}
