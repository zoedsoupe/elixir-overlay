# elixir-overlay

*Pure and reproducible* packaging of Elixir releases.
A Nix overlay providing access to different Elixir versions for reproducible development environments.

Features:

- Hashes of Elixir releases are pre-fetched in tree, so the evaluation is
  *pure* and no need to have network access.

- Supports multiple Elixir versions from official releases.

- Compatible with both classic Nix overlays and Nix Flakes.

- Targets nixos-unstable and supported releases of NixOS.

## Installation

### Classic Nix overlay

You can put the code below into your `~/.config/nixpkgs/overlays.nix`.
```nix
[ (import (builtins.fetchTarball "https://github.com/your-username/elixir-overlay/archive/main.tar.gz")) ]
```
Then the provided attribute paths are available in nix command.
```bash
$ nix-env -iA nixpkgs.elixir-bin.latest # Install latest Elixir version
$ nix-env -iA nixpkgs.elixir-bin."1.17.0" # Install specific version
```

Alternatively, you can install it into nix channels.
```bash
$ nix-channel --add https://github.com/your-username/elixir-overlay/archive/main.tar.gz elixir-overlay
$ nix-channel --update
```
And then feel free to use it anywhere like
`import <nixpkgs> { overlays = [ (import <elixir-overlay>) ]; }` in your nix shell environment.

### Nix Flakes

For a quick play, just use `nix shell` to bring the latest Elixir into scope.
```shell
$ nix shell github:your-username/elixir-overlay
$ elixir --version
```

#### Use in NixOS Configuration

Here's an example of using it in nixos configuration.
```nix
{
  description = "My configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    elixir-overlay = {
      url = "github:your-username/elixir-overlay";
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

#### Use in `devShell` for `nix develop`

Running `nix develop` will create a shell with Elixir installed:

```nix
{
  description = "A devShell example";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixos-unstable";
    elixir-overlay.url = "github:your-username/elixir-overlay";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, elixir-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import elixir-overlay) ];
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

## Cheat sheet: common usage of `elixir-bin`

- Latest Elixir version:
  ```nix
  elixir-bin.latest
  ```

- Specific Elixir version:
  ```nix
  elixir-bin."1.17.0"
  elixir-bin."1.16.3"
  ```

## License

MIT licensed.