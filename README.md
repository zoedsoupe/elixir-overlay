# elixir-overlay

Pure and reproducible Elixir overlays for Nix. Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay), providing all Elixir versions with automatic updates and OTP compatibility tracking.

## Why elixir-overlay?

- **All Elixir versions**: Access to any Elixir version from 1.15.0 to latest (1.18.4), including release candidates
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
          elixir-bin.latest          # Latest Elixir (1.18.4)
          elixir-bin."1.17.3"        # Specific version
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

### With direnv

Create `.envrc`:

```bash
use flake github:zoedsoupe/elixir-overlay
```

### Legacy Nix

```nix
let
  elixir-overlay = import (builtins.fetchTarball 
    "https://github.com/zoedsoupe/elixir-overlay/archive/main.tar.gz");
  pkgs = import <nixpkgs> { overlays = [ elixir-overlay ]; };
in
  pkgs.mkShell {
    buildInputs = [ pkgs.elixir-bin.latest ];
  }
```

## Available Versions

All Elixir versions from **1.15.0** to **1.18.4** are available, including release candidates (RC versions), with automatic OTP compatibility tracking:

| Elixir Version | Min OTP | Max OTP | Status |
|----------------|---------|---------|--------|
| 1.19.x-rc      | 25      | 28      | Release Candidate |
| 1.18.x         | 25      | 28      | Current |
| 1.17.x         | 25      | 27      | Maintained |
| 1.16.x         | 24      | 27      | Supported |
| 1.15.x         | 24      | 26      | Supported |

## Package Names

Elixir versions are available using the following patterns:

- `pkgs.elixir-bin.latest` - Latest stable version (1.18.4)
- `pkgs.elixir-bin."1.18.4"` - Specific version with quotes
- `pkgs.elixir-bin."1.19.0-rc.0"` - Release candidate versions
- `packages.elixir_1_18_4` - Flake package (dots replaced with underscores)
- `packages.elixir_1_19_0-rc_0` - RC flake package (dots and hyphens replaced with underscores)

## Usage Examples

### Phoenix Development

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
  };

  outputs = { nixpkgs, elixir-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ elixir-overlay.overlays.default ];
      };
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          elixir-bin."1.18.4"
          postgresql
          nodejs
          inotify-tools  # For Phoenix live reload
        ];
        
        shellHook = ''
          export MIX_ENV=dev
          export PHX_SERVER=true
        '';
      };
    };
}
```

### Multiple Elixir Versions

```nix
# shell.nix
let
  elixir-overlay = import (builtins.fetchTarball {
    url = "https://github.com/zoedsoupe/elixir-overlay/archive/main.tar.gz";
  });
  pkgs = import <nixpkgs> { overlays = [ elixir-overlay ]; };
in
pkgs.mkShell {
  buildInputs = with pkgs.elixir-bin; [
    "1.17.3"  # Legacy project
    "1.18.4"  # New project
  ];
  
  shellHook = ''
    # Create aliases for different versions
    alias elixir17="${pkgs.elixir-bin."1.17.3"}/bin/elixir"
    alias elixir18="${pkgs.elixir-bin."1.18.4"}/bin/elixir"
    alias mix17="${pkgs.elixir-bin."1.17.3"}/bin/mix"
    alias mix18="${pkgs.elixir-bin."1.18.4"}/bin/mix"
  '';
}
```

### NixOS Configuration

```nix
{
  description = "My configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    elixir-overlay = {
      url = "github:zoedsoupe/elixir-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, elixir-overlay, ... }: {
    nixosConfigurations = {
      hostname = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix # Your system configuration.
          ({ pkgs, ... }: {
            nixpkgs.overlays = [ elixir-overlay.overlays.default ];
            environment.systemPackages = [ pkgs.elixir-bin.latest ];
          })
        ];
      };
    };
  };
}
```

### Development Shell with `nix develop`

```nix
{
  description = "A devShell example";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    elixir-overlay.url = "github:zoedsoupe/elixir-overlay";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, elixir-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ elixir-overlay.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
      in
      {
        devShells.default = with pkgs; mkShell {
          buildInputs = [
            elixir-bin.latest
            # Or specific version: elixir-bin."1.17.0"
          ];
        };
      }
    );
}
```

## Automation

The overlay automatically updates daily via GitHub Actions:

- **Daily scans** for new Elixir releases
- **Auto-generated PRs** when new versions are found
- **SHA256 verification** for all downloads
- **OTP compatibility** automatically determined
- **Nix expression generation** following nixpkgs patterns

The automation is powered by a native Elixir script (`scripts/fetch_elixir.exs`) that:
- Uses Mix.install for dependencies (Req HTTP client)
- Leverages Elixir 1.18's native JSON library
- Integrates with GitHub API for release detection
- Detects both stable releases and release candidates (RC versions)
- Calculates proper OTP version ranges
- Uses nix-prefetch-url for SHA256 generation

## Cheat Sheet: Common Usage

- **Latest Elixir version:**
  ```nix
  elixir-bin.latest
  ```

- **Specific Elixir versions:**
  ```nix
  elixir-bin."1.18.4"
  elixir-bin."1.17.3"
  elixir-bin."1.16.0"
  elixir-bin."1.19.0-rc.0"  # Release candidates
  ```

- **Legacy channel installation:**
  ```bash
  $ nix-channel --add https://github.com/zoedsoupe/elixir-overlay/archive/main.tar.gz elixir-overlay
  $ nix-channel --update
  $ nix-env -iA nixpkgs.elixir-bin.latest
  ```

- **Classic overlay in ~/.config/nixpkgs/overlays.nix:**
  ```nix
  [ (import (builtins.fetchTarball "https://github.com/zoedsoupe/elixir-overlay/archive/main.tar.gz")) ]
  ```

## Contributing

### Running the Update Script

```bash
# Fetch latest Elixir releases
./scripts/fetch_elixir.exs

# Test a specific version
nix build .#elixir_1_18_4
nix run .#elixir_1_18_4 -- --version
```

### Adding New Versions Manually

1. Edit `manifests/stable/default.nix`
2. Add version entry with SHA256 hash:

```nix
"1.19.0" = {
  sha256 = "0abc123...";
  url = "https://codeload.github.com/elixir-lang/elixir/tar.gz/refs/tags/v1.19.0";
  minOtpVersion = "26";
  maxOtpVersion = "29";
};
```

3. Update `latest` in `lib/manifests.nix` if needed

### Development

```bash
# Enter development shell
nix develop

# Test all versions
nix flake check

# Build specific version
nix build .#elixir_1_17_3
```

## Acknowledgments

- Inspired by [rust-overlay](https://github.com/oxalica/rust-overlay) by oxalica
- Built on [nixpkgs](https://github.com/NixOS/nixpkgs) Elixir derivation patterns
- Powered by the amazing [Nix](https://nixos.org/) package manager

## License

MIT License - see [LICENSE](LICENSE) for details.