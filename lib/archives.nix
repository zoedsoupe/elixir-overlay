{
  lib,
  pkgs,
  elixir,
  erlang,
}: let
  manifestDirectory = ../manifests/archives;

  buildArchive = package: version: manifest:
    pkgs.stdenv.mkDerivation {
      pname = package;
      inherit version;

      src = pkgs.beamPackages.fetchHex {
        pkg = package;
        inherit version;
        sha256 = manifest.sha256;
      };

      nativeBuildInputs = [elixir erlang];
      dontConfigure = true;
      doCheck = false;

      MIX_ENV = "prod";
      HEX_OFFLINE = "1";

      preBuild = ''
        substituteInPlace mix.exs --replace-fail 'deps: deps(),' 'deps: [],'
      '';

      buildPhase = ''
        runHook preBuild

        export HOME="$TMPDIR/home"
        export MIX_HOME="$TMPDIR/mix"
        export HEX_HOME="$TMPDIR/hex"
        export MIX_BUILD_PATH="$TMPDIR/build"
        export MIX_DEPS_PATH="$TMPDIR/deps"
        mkdir -p "$HOME" "$MIX_HOME" "$HEX_HOME" "$MIX_BUILD_PATH" "$MIX_DEPS_PATH"

        mix archive.build -o "$TMPDIR/${package}-${version}.ez"

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/lib/mix/archives"
        install -m 644 "$TMPDIR/${package}-${version}.ez" "$out/lib/mix/archives/"
        runHook postInstall
      '';

      passthru = {
        minElixirVersion = manifest.minElixirVersion;
      };

      meta = {
        description = "${package} Mix archive";
        platforms = lib.platforms.unix;
      };
    };

  packageSet = package: let
    directory = manifestDirectory + "/${package}";
    manifestFiles =
      lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".json" name)
      (builtins.readDir directory);
    versions = lib.listToAttrs (map (file: let
      version = lib.removeSuffix ".json" file;
    in {
      name = version;
      value = builtins.fromJSON (builtins.readFile (directory + "/${file}"));
    }) (lib.attrNames manifestFiles));
    versionNames = lib.attrNames versions;
    sortVersions = names: lib.sort (left: right: lib.versionOlder left right) names;
    latestVersion = lib.last (sortVersions versionNames);
    versionPackages = lib.mapAttrs (version: manifest:
      buildArchive package version manifest)
    versions;

    latestForPrefix = prefix: let
      matching = builtins.filter (version:
        version == prefix || lib.hasPrefix "${prefix}." version)
      versionNames;
    in
      versionPackages.${lib.last (sortVersions matching)};

    majorAliases = lib.unique (map (version:
      builtins.head (lib.splitString "." version))
    versionNames);
    minorAliases = lib.unique (map (version: let
      parts = lib.splitString "." version;
    in "${builtins.elemAt parts 0}.${builtins.elemAt parts 1}")
    versionNames);

    aliases = lib.listToAttrs (
      map (version: {
        name = version;
        value = latestForPrefix version;
      })
      (majorAliases ++ minorAliases)
    );
  in
    versionPackages
    // aliases
    // {
      latest = versionPackages.${latestVersion};
    };

  hexArchive = let
    hex = pkgs.beamPackages.hex;
  in
    pkgs.runCommand "hex-${hex.version}-archive" {
      nativeBuildInputs = [elixir erlang];
    } ''
      mkdir -p "$out/lib/mix/archives"
      mix archive.build \
        --no-compile \
        -i ${hex}/lib/erlang/lib/hex \
        -o "$out/lib/mix/archives/hex-${hex.version}.ez"
    '';
in {
  inherit hexArchive;
  phx_new = packageSet "phx_new";
  igniter_new = packageSet "igniter_new";
}
