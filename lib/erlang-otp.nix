{
  lib,
  pkgs,
}: let
  nixpkgsPath = pkgs.path;
  genericBuilderPath = nixpkgsPath + "/pkgs/development/interpreters/erlang/generic-builder.nix";
  legacyPlatforms = [
    "aarch64-darwin"
    "x86_64-linux"
  ];
  manifestDirectory = ../manifests/erlang-otp;
  manifestFiles =
    lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".json" name)
    (builtins.readDir manifestDirectory);

  versions = lib.listToAttrs (map (file: let
    version = lib.removeSuffix ".json" file;
  in {
    name = version;
    value = builtins.fromJSON (builtins.readFile (manifestDirectory + "/${file}"));
  }) (lib.attrNames manifestFiles));

  mkGenericBuilder = versionArgs:
    import genericBuilderPath (versionArgs
      // {
        systemdSupport = false;
      });

  build = {
    version,
    hash,
    wxSupport ? false,
  }: let
    major = builtins.head (lib.splitString "." version);

    buildLegacy = (pkgs.callPackage (mkGenericBuilder {inherit version hash wxSupport;}) {}).overrideAttrs (old: {
      meta =
        (old.meta or {})
        // {
          platforms = legacyPlatforms;
        };
    });

    buildModern = let
      majorBuilderPath = nixpkgsPath + "/pkgs/development/interpreters/erlang/${major}.nix";
      genericBuilder = versionArgs:
        mkGenericBuilder (versionArgs // {inherit version hash wxSupport;});
    in
      (pkgs.callPackage (import majorBuilderPath genericBuilder) {}).overrideAttrs (_: {
        installTargets = ["install"];
      });
  in
    if major == "26"
    then buildLegacy.overrideAttrs (_: {installTargets = ["install"];})
    else if builtins.elem major ["27" "28" "29"]
    then buildModern
    else throw "beam-overlay: unsupported Erlang/OTP family `${major}`.";

  versionNames = lib.attrNames versions;
  sortVersions = names: lib.sort (left: right: lib.versionOlder left right) names;
  sortedVersionNames = sortVersions versionNames;
  latestVersion = lib.last sortedVersionNames;
  versionPackages = lib.mapAttrs (version: manifest:
    build {
      inherit version;
      inherit (manifest) hash;
    })
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

  packages =
    versionPackages
    // aliases
    // {
      latest = versionPackages.${latestVersion};
    };
in {
  inherit build packages versions latestVersion legacyPlatforms;
}
