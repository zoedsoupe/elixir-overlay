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

  selectedBeamPackages =
    if selectedElixir == null
    then null
    else
      pkgs.beamPackages.extend (_: _: {
        elixir = selectedElixir;
        erlang = selectedOtp;
      });

  archivePackageSets =
    if selectedElixir == null
    then {}
    else
      import ./archives.nix {
        inherit lib pkgs;
        elixir = selectedElixir;
        erlang = selectedOtp;
      };

  selectArchive = name: archiveOptions:
    if !archiveOptions.enable
    then null
    else let
      packages = archivePackageSets.${name};
    in
      if archiveOptions.version == "latest"
      then packages.latest
      else if builtins.hasAttr archiveOptions.version packages
      then builtins.getAttr archiveOptions.version packages
      else throw "beam-overlay: unknown tools.${name} version `${archiveOptions.version}`.";

  selectedPhxNew = selectArchive "phx_new" options.tools.phx_new;
  selectedIgniterNew = selectArchive "igniter_new" options.tools.igniter_new;
  selectedArchives = builtins.filter (archive: archive != null) [selectedPhxNew selectedIgniterNew];
  incompatibleArchive =
    lib.findFirst (archive:
      lib.versionOlder selectedElixir.version archive.minElixirVersion)
    null
    selectedArchives;

  archiveStore =
    if selectedArchives == []
    then null
    else
      pkgs.symlinkJoin {
        name = "beam-mix-archives";
        paths = [archivePackageSets.hexArchive] ++ selectedArchives;
      };

  mixWrapper =
    if archiveStore == null
    then null
    else
      pkgs.writeShellScriptBin "mix" ''
        export MIX_ARCHIVES="${archiveStore}/lib/mix/archives"
        exec "${selectedElixir}/bin/mix" "$@"
      '';

  selectedLivebook =
    if options.tools.livebook.enable
    then pkgs.livebook
    else null;

  selectedTailwindcss =
    if options.tools.tailwindcss.enable
    then builtins.getAttr "tailwindcss_${toString options.tools.tailwindcss.major}" pkgs
    else null;

  selectedEsbuild =
    if options.tools.esbuild.enable
    then pkgs.esbuild
    else null;

  selectedToolPackages = builtins.filter (package: package != null) [
    selectedLivebook
    selectedTailwindcss
    selectedEsbuild
  ];

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
    ++ selectedToolPackages
    ++ options.extraPackages;

  baseToolchain = pkgs.buildEnv {
    name = "beam-toolchain";
    paths = packagePaths;
    pathsToLink = ["/bin"];
  };

  toolchain =
    if mixWrapper == null
    then baseToolchain
    else
      pkgs.symlinkJoin {
        name = "beam-toolchain";
        paths = [baseToolchain];
        postBuild = ''
          rm "$out/bin/mix"
          ln -s ${mixWrapper}/bin/mix "$out/bin/mix"
        '';
      };
in
  builtins.deepSeq (builtins.removeAttrs options ["extraPackages"]) (
    if !otpIsCompatible && requestedOtpBase != null
    then throw "beam-overlay: Erlang/OTP ${otpMajor} is incompatible with Elixir ${selectedElixir.version}; supported range is ${requiredOtp.min or "unknown"}–${requiredOtp.max or "unknown"}."
    else if incompatibleArchive != null
    then throw "beam-overlay: tools.${incompatibleArchive.pname} ${incompatibleArchive.version} requires Elixir ${incompatibleArchive.minElixirVersion} or later; selected Elixir is ${selectedElixir.version}."
    else
      toolchain
      // {
        beamScope = {
          elixir = selectedElixir;
          erlang = selectedOtp;
          mixRelease =
            if selectedBeamPackages == null
            then null
            else selectedBeamPackages.mixRelease;
          fetchMixDeps =
            if selectedBeamPackages == null
            then null
            else selectedBeamPackages.fetchMixDeps;
          archives = {
            phx_new = selectedPhxNew;
            igniter_new = selectedIgniterNew;
          };
          tools = {
            livebook = selectedLivebook;
            tailwindcss = selectedTailwindcss;
            esbuild = selectedEsbuild;
          };
        };
      }
  )
