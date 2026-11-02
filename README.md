# elixir-overlay

Pure and reproducible BEAM packages and runtime helpers for Nix. Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay), providing all Elixir versions with automatic updates and OTP compatibility tracking.

## Why `elixir-overlay`?

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
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
  };

  outputs = { self, nixpkgs, elixir-overlay }:
    let
      system = "x86_64-linux"; # or "aarch64-darwin", etc.
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ elixir-overlay.overlays.default ];
      };
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          elixir-bin.latest          # Latest Elixir
          elixir-bin."1.18.6"        # Specific version
        ];
      };
    };
}
```

### Quick Shell

For a quick play, just use `nix shell` to bring the latest Elixir into scope:

```shell
$ nix shell github:zoedsoupe/elixir-overlay
$ elixir --version
```

## Available Versions

All Elixir versions starting from **1.15.0** are available, including release candidates (RC versions), with automatic OTP compatibility tracking following the official [compatibility table](https://elixir.hexdocs.pm/compatibility-and-deprecations.html#between-elixir-and-erlang-otp)

## Package Names

Elixir versions are available using the following patterns:

- `pkgs.elixir-bin.latest` - Latest stable version
- `pkgs.elixir-bin."1.18.4"` - Specific version with quotes
- `pkgs.elixir-bin."1.19.0-rc.0"` - Release candidate versions

## Custom OTP/Erlang Version

You can override the OTP version used to compile Elixir using the `elixir-with-otp` function, otherwise the latest compatible otp version is used by default:

```nix
# flake.nix
{
  outputs = { nixpkgs, elixir-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ elixir-overlay.overlays.default ];
      };

      # Create custom Elixir packages with specific OTP versions
      elixir-with-otp26 = pkgs.elixir-with-otp pkgs.erlang_26;
      elixir-with-otp27 = pkgs.elixir-with-otp pkgs.erlang_27;
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          elixir-with-otp26."1.19.0-rc.0"
          elixir-with-otp27.latest
        ];
      };
    };
}
```

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

`mkPhoenixRelease` adds Tailwind/esbuild binary discovery and runs `assets.deploy --no-deps-check` before creating the release. Set `tailwindcss = null` or `esbuild = null` when the application does not use that integration, or `assetsDeploy = false` to disable the asset convention entirely.

When using `mixDepsHash`, `mixDepsArgs` can pass additional environment and hooks to `fetchMixDeps`. This is useful for native dependencies that must be configured or fetched inside the fixed-output derivation:

```nix
pkgs.beam-overlay.mkMixRelease {
  inherit toolchain pname version src mixDepsHash;
  mixDepsArgs = {
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
  imports = [inputs.elixir-overlay.nixosModules.beam];

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

### Docker images

Use `lib.mkBeamImage` with the package set appropriate for the image target:

```nix
image = inputs.elixir-overlay.lib.mkBeamImage {
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

The result is a layered Docker image tarball. Additional Docker configuration can be merged through the `config` argument. Building the OCI artifact is a packaging concern; running it belongs to NixOS' existing `virtualisation.oci-containers` module. The BEAM systemd module deliberately does not duplicate container runtime, networking, or restart policy options.

## Acknowledgments

- Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay) by oxalica
- Built on [nixpkgs](https://github.com/NixOS/nixpkgs) Elixir derivation patterns
- Powered by the amazing [Nix](https://nixos.org/) package manager

## License

MIT License - see [LICENSE](LICENSE) for details.
