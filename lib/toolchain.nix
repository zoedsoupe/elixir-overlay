{
  lib,
  pkgs,
  defaultElixirPackages,
  elixirWithOtp,
  erlangOtp,
}: rawOptions: let
  options = import ./options.nix {inherit lib;} rawOptions;
  otpOptions = options."erlang-otp";

  requestedOtpBase =
    if otpOptions.version == null
    then null
    else if builtins.hasAttr otpOptions.version erlangOtp.packages
    then builtins.getAttr otpOptions.version erlangOtp.packages
    else throw "beam-overlay: unknown Erlang/OTP version `${otpOptions.version}`.";

  baseElixirPackages =
    if requestedOtpBase == null
    then defaultElixirPackages
    else elixirWithOtp requestedOtpBase;

  selectElixir = packages:
    if !options.elixir.enable
    then null
    else if options.elixir.version == "latest"
    then packages.latest
    else if builtins.hasAttr options.elixir.version packages
    then builtins.getAttr options.elixir.version packages
    else throw "beam-overlay: unknown Elixir version `${options.elixir.version}`.";

  baseSelectedElixir = selectElixir baseElixirPackages;

  baseSelectedOtp =
    if baseSelectedElixir != null
    then baseSelectedElixir.erlang
    else if requestedOtpBase != null
    then requestedOtpBase
    else erlangOtp.packages.latest;

  selectedOtp =
    if !otpOptions.wxSupport
    then baseSelectedOtp
    else let
      manifest = erlangOtp.versions.${baseSelectedOtp.version} or null;
    in
      if manifest == null
      then throw "beam-overlay: Erlang/OTP ${baseSelectedOtp.version} has no manifest for wx-enabled builds."
      else
        erlangOtp.build {
          version = baseSelectedOtp.version;
          inherit (manifest) hash;
          wxSupport = true;
        };

  selectedElixirPackages =
    if requestedOtpBase != null || otpOptions.wxSupport
    then elixirWithOtp selectedOtp
    else defaultElixirPackages;

  selectedElixir = selectElixir selectedElixirPackages;
  otpMajor = lib.head (lib.splitString "." selectedOtp.version);
  requiredOtp =
    if selectedElixir == null
    then {}
    else (selectedElixir.requiredOtpVersion or {});
  otpAtLeastMinimum =
    (requiredOtp.min or null) == null || !lib.versionOlder otpMajor requiredOtp.min;
  otpAtMostMaximum =
    (requiredOtp.max or null) == null || !lib.versionOlder requiredOtp.max otpMajor;
  otpIsCompatible = otpAtLeastMinimum && otpAtMostMaximum;

  packagePaths =
    [selectedOtp]
    ++ (
      if selectedElixir == null
      then []
      else [selectedElixir]
    )
    ++ options.extraPackages;

  toolchain = pkgs.buildEnv {
    name = "beam-toolchain";
    paths = packagePaths;
    pathsToLink = ["/bin"];
  };
in
  builtins.deepSeq (builtins.removeAttrs options ["extraPackages"]) (
    if !otpIsCompatible && requestedOtpBase != null
    then throw "beam-overlay: Erlang/OTP ${otpMajor} is incompatible with Elixir ${selectedElixir.version}; supported range is ${requiredOtp.min or "unknown"}–${requiredOtp.max or "unknown"}."
    else
      toolchain
      // {
        beamScope = {
          elixir = selectedElixir;
          erlang = selectedOtp;
        };
      }
  )
