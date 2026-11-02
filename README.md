# elixir-overlay

Pure and reproducible Elixir overlays for Nix. Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay), providing all Elixir versions with automatic updates and OTP compatibility tracking.

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

## Acknowledgments

- Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay) by oxalica
- Built on [nixpkgs](https://github.com/NixOS/nixpkgs) Elixir derivation patterns
- Powered by the amazing [Nix](https://nixos.org/) package manager

## License

MIT License - see [LICENSE](LICENSE) for details.
