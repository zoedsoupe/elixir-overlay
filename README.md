# beam-overlay

Pure and reproducible BEAM packages and runtime helpers for Nix. Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay), providing all Elixir versions with automatic updates and OTP compatibility tracking.

## Why `beam-overlay`?

- **All Elixir versions**: Access to any Elixir version from `1.15.0` to latest, including release candidates
- **Automatic updates**: Daily automated checks for new releases with auto-generated PRs
- **OTP compatibility**: Built-in tracking of OTP version compatibility for each Elixir version
- **Zero maintenance**: No manual hash updates or version management needed
- **Reproducible**: Pinned SHA256 hashes ensure reproducible builds across all environments
- **Pure evaluation**: Hashes are pre-fetched in tree, no network access needed during evaluation

## Quick Start

### With Flakes

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    beam-overlay.url = "github:zoedsoupe/beam-overlay";
  };

  outputs = { self, nixpkgs, beam-overlay }:
    let
      system = "x86_64-linux"; # or "aarch64-darwin", etc.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ beam-overlay.overlays.default ];
      };
      beam = pkgs.beam-overlay.mkToolchain {
        elixir.version = "1.19.7";
        erlang-otp.version = "28";
      };
    in {
      devShells.default = pkgs.mkShell {
        packages = [ beam ];
      };
    };
}
```

See the runnable [development-shell example](examples/dev-shell/flake.nix) for a toolchain with Mix archives and asset tools.

### Quick Shell

For a quick play, just use `nix shell` to bring the latest Elixir into scope:

```shell
$ nix shell github:zoedsoupe/beam-overlay
$ elixir --version
```

## Available Versions

All Elixir versions starting from **1.15.0** are available, including release candidates (RC versions), with automatic OTP compatibility tracking following the official [compatibility table](https://elixir.hexdocs.pm/compatibility-and-deprecations.html#between-elixir-and-erlang-otp)

## Package Names

Elixir versions are available through `pkgs.beam-overlay.elixir`:

- `pkgs.beam-overlay.elixir.latest` - Latest stable version
- `pkgs.beam-overlay.elixir."1.18.4"` - Specific version with quotes
- `pkgs.beam-overlay.elixir."1.19.0-rc.0"` - Release candidate versions

## Custom OTP/Erlang Version

Select the Elixir and OTP versions together with `mkToolchain`:

```nix
# flake.nix
{
  outputs = { nixpkgs, beam-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ beam-overlay.overlays.default ];
      };

      toolchain = pkgs.beam-overlay.mkToolchain {
        elixir.version = "1.19.7";
        erlang-otp.version = "28";
      };
    in {
      devShells.default = pkgs.mkShell {
        packages = [ toolchain ];
      };
    };
}
```

If no OTP version is specified, the toolchain selects the newest compatible OTP release. Set `elixir.enable = false` to create an Erlang-only environment.

## Binary cache

The flake advertises the public Cachix substituter for prebuilt packages. Accept the flake's Nix configuration when prompted, or add `https://elixir-overlay.cachix.org` as a substituter and trust `elixir-overlay.cachix.org-1:03zcUxISSuNn2vnKPfUJFinDGU5vzhyc+cPbB7u77xA=`.

## Mix and Phoenix releases

Create a toolchain once, then pass it to the generic Mix builder or the Phoenix-specific wrapper:

```nix
let
  beam = pkgs.beam-overlay.mkToolchain {
    elixir.version = "1.19.7";
    erlang-otp.version = "28";
  };
in {
  packages.mix-app = pkgs.beam-overlay.mkMixRelease {
    toolchain = beam;
    pname = "mix-app";
    version = "0.1.0";
    src = ./.;
    mixDepsHash = "sha256-...";
  };

  packages.phoenix-app = pkgs.beam-overlay.mkPhoenixRelease {
    toolchain = beam;
    pname = "phoenix-app";
    version = "0.1.0";
    src = ./.;
    mixDepsHash = "sha256-...";
  };
}
```

Both builders accept exactly one dependency strategy: `mixDepsHash`, `mixFodDeps`, or non-empty `mixNixDeps`. Other attributes are forwarded to nixpkgs' `mixRelease`.

`mkPhoenixRelease` writes the Tailwind/esbuild store binary paths into `config/config.exs`, disables their wrapper version checks, and runs `assets.deploy --no-deps-check` before creating the release. It does not evaluate `config/runtime.exs` for asset discovery, so production secrets are not needed at build time. Set `tailwindcss = null` or `esbuild = null` when the application does not use that integration, or `assetsDeploy = false` to disable the asset convention entirely.

When using `mixDepsHash`, `mixDepsArgs` can pass additional environment and hooks to `fetchMixDeps`. This is useful for native dependencies that must be configured or fetched inside the fixed-output derivation:

```nix
pkgs.beam-overlay.mkMixRelease {
  inherit toolchain pname version src mixDepsHash;
  mixDepsArgs = {
    # Prevent patchShebangs from adding store references to vendored scripts.
    dontPatchShebangs = true;
    env.MDEX_NATIVE_BUILD = "1";
    preInstall = ''
      export CARGO_HOME="$TEMPDIR/cargo-home"
    '';
    postInstall = ''
      ${pkgs.cargo}/bin/cargo vendor --locked \
        --manifest-path "$out/mdex_native/native/mdex_native_nif/Cargo.toml" \
        "$out/cargo-vendor"
    '';
  };

  env.MDEX_NATIVE_BUILD = "1";
  nativeBuildInputs = [pkgs.cargo pkgs.rustc];
}
```

The application remains responsible for configuring Cargo to use the vendored sources during the offline release build. `mixDepsArgs` is rejected with the other dependency strategies because it only applies to the builder-managed `fetchMixDeps` call.

## BEAM runtime helpers

Runtime helpers are exposed independently of the Nix overlay. They accept any release package; importing them does not require using `mkToolchain` or the release builders.

### Systemd services on NixOS

Import `nixosModules.beam` and declare applications under `services.beam.apps`:

```nix
{
  imports = [inputs.beam-overlay.nixosModules.beam];

  services.beam.apps.blog = {
    enable = true;
    package = blogRelease;
    command = "bin/server";
    preStart = ["${blogRelease}/bin/migrate"];

    environment = {
      PHX_SERVER = "true";
      PHX_HOST = "blog.example.com";
      PORT = "4000";
    };
    environmentFiles = ["/etc/beam/blog.env"];
    stateDir = "/var/lib/blog/data";
  };
}
```

The module creates per-application users, state directories, and hardened systemd services. `arguments` passes arguments to `command`, and `extraServiceConfig` provides a systemd escape hatch. Phoenix environment, migrations, and distribution policy remain application configuration rather than module defaults.

### OCI containers on NixOS

Import `nixosModules.beam` and declare published images under `services.beam.containers`:

```nix
{
  imports = [inputs.beam-overlay.nixosModules.beam];

  services.beam.containers.blog = {
    enable = true;
    image = "ghcr.io/example/blog:1.2.3";
    uid = 33333;
    gid = 33333;
    dataDir = "/zdata/blog";
    requiredMounts = ["/zdata"];
    port = 4000;
    environment = {
      PHX_SERVER = "true";
      PHX_HOST = "blog.example.com";
    };
    environmentFiles = ["/etc/beam/blog.env"];
  };
}
```

The module creates the service user and group, mounts `dataDir` at `/data`, publishes `port` on `listenAddress`, and runs the container through NixOS' Docker-backed `virtualisation.oci-containers` module. Images must use an explicit non-`latest` tag or a SHA-256 digest. `requiredMounts` are checked before startup.

`volumes` adds mounts beyond the managed data directory. `entrypoint` and `cmd` override image execution. `extraContainerConfig` and `extraServiceConfig` are the escape hatches for upstream container and systemd settings. Application-specific companion modules can contribute environment, files, volumes, and additional services without redeclaring this deployment API.

### Docker images

Use `lib.mkBeamImage` with the package set appropriate for the image target:

```nix
image = inputs.beam-overlay.lib.mkBeamImage {
  inherit pkgs;
  name = "blog";
  package = blogRelease;
  command = ["${blogRelease}/bin/server"];

  environment = {
    PHX_SERVER = "true";
    PORT = 4000;
  };
  contents = [pkgs.cacert];
  exposedPorts = {
    "4000/tcp" = {};
  };
};
```

The result is a layered Docker image tarball. Additional Docker configuration can be merged through the `config` argument. Use `services.beam.containers` to run a published image, or NixOS' existing `virtualisation.oci-containers` module when the shared deployment conventions are not wanted.

## Acknowledgments

- Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay) by oxalica
- Built on [nixpkgs](https://github.com/NixOS/nixpkgs) Elixir derivation patterns
- Powered by the amazing [Nix](https://nixos.org/) package manager

## License

MIT License - see [LICENSE](LICENSE) for details.
