{
  lib,
  pkgs,
  mkMixRelease,
}: {
  toolchain,
  assetsDeploy ? true,
  tailwindcss ? pkgs.tailwindcss_4,
  esbuild ? pkgs.esbuild,
  ...
} @ args: let
  configureTailwind = lib.optionalString (assetsDeploy && tailwindcss != null) ''
    cat >> config/config.exs <<'EOF'
    config :tailwind, path: "${tailwindcss}/bin/tailwindcss", version_check: false
    EOF
  '';

  configureEsbuild = lib.optionalString (assetsDeploy && esbuild != null) ''
    cat >> config/config.exs <<'EOF'
    config :esbuild, path: "${esbuild}/bin/esbuild", version_check: false
    EOF
  '';

  # Do not use `mix run` to discover wrapper paths: it evaluates runtime.exs,
  # which commonly requires production secrets that do not belong in a build.
  generatedPreConfigure = configureTailwind + configureEsbuild;
  generatedPreInstall = lib.optionalString assetsDeploy ''
    ${toolchain}/bin/mix assets.deploy --no-deps-check
  '';

  appendHook = name: generated: let
    existing = args.${name} or "";
  in
    lib.concatStringsSep "\n" (builtins.filter (hook: hook != "") [existing generated]);

  forwardedArgs = builtins.removeAttrs args [
    "assetsDeploy"
    "tailwindcss"
    "esbuild"
  ];
in
  mkMixRelease (
    forwardedArgs
    // {
      preConfigure = appendHook "preConfigure" generatedPreConfigure;
      preInstall = appendHook "preInstall" generatedPreInstall;
    }
  )
