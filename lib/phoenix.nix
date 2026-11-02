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
  queryBinPath = module: ''
    ${toolchain}/bin/mix run \
      --no-compile \
      --no-deps-check \
      --no-start \
      -e 'IO.write(${module}.bin_path())'
  '';

  linkTailwind = lib.optionalString (assetsDeploy && tailwindcss != null) ''
    tailwind_bin_path="$(${queryBinPath "Tailwind"})"
    mkdir -p "$(dirname "$tailwind_bin_path")"
    ln -sfn ${tailwindcss}/bin/tailwindcss "$tailwind_bin_path"
  '';

  linkEsbuild = lib.optionalString (assetsDeploy && esbuild != null) ''
    esbuild_bin_path="$(${queryBinPath "Esbuild"})"
    mkdir -p "$(dirname "$esbuild_bin_path")"
    ln -sfn ${esbuild}/bin/esbuild "$esbuild_bin_path"
  '';

  generatedPostConfigure = linkTailwind + linkEsbuild;
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
      postConfigure = appendHook "postConfigure" generatedPostConfigure;
      preInstall = appendHook "preInstall" generatedPreInstall;
    }
  )
