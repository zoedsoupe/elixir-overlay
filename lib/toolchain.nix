{
  lib,
  pkgs,
  defaultElixirPackages,
  elixirWithOtp,
}: rawOptions: let
  options = import ./options.nix {inherit lib;} rawOptions;
  otpOptions = options."erlang-otp";

  isOtpPackageAvailable = name:
    (builtins.tryEval (builtins.deepSeq (builtins.getAttr name pkgs).version true)).success;

  availableOtpAttributes =
    builtins.filter
    (name: builtins.match "erlang_[0-9]+" name != null && isOtpPackageAvailable name)
    (builtins.attrNames pkgs);
  otpAttributeVersion = name: lib.removePrefix "erlang_" name;

  latestNixpkgsOtp = let
    sorted =
      lib.sort
      (left: right: lib.versionOlder (otpAttributeVersion left) (otpAttributeVersion right))
      availableOtpAttributes;
  in
    if sorted == []
    then throw "beam-overlay: nixpkgs provides no versioned Erlang/OTP packages."
    else builtins.getAttr (builtins.last sorted) pkgs;

  requestedOtp =
    if otpOptions.version == null
    then null
    else let
      attribute = "erlang_${otpOptions.version}";
      packageAvailable = builtins.hasAttr attribute pkgs && isOtpPackageAvailable attribute;
    in
      if packageAvailable
      then builtins.getAttr attribute pkgs
      else throw "beam-overlay: Erlang/OTP version `${otpOptions.version}` is unavailable in the selected nixpkgs.";

  elixirPackages =
    if requestedOtp == null
    then defaultElixirPackages
    else elixirWithOtp requestedOtp;

  selectedElixir =
    if !options.elixir.enable
    then null
    else if options.elixir.version == "latest"
    then elixirPackages.latest
    else if builtins.hasAttr options.elixir.version elixirPackages
    then builtins.getAttr options.elixir.version elixirPackages
    else throw "beam-overlay: unknown Elixir version `${options.elixir.version}`.";

  selectedOtp =
    if selectedElixir != null
    then selectedElixir.erlang
    else if requestedOtp != null
    then requestedOtp
    else latestNixpkgsOtp;

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
    if !otpIsCompatible && requestedOtp != null
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
