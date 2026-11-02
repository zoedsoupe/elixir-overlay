{
  description = "A BEAM development shell using beam-overlay";

  inputs = {
    beam-overlay.url = "path:../..";
    nixpkgs.follows = "beam-overlay/nixpkgs";
  };

  outputs = {
    nixpkgs,
    beam-overlay,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
  in {
    devShells = nixpkgs.lib.genAttrs systems (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [beam-overlay.overlays.default];
      };

      toolchain = pkgs.beam-overlay.mkToolchain {
        elixir.version = "1.19.7";
        erlang-otp.version = "28";
        tools = {
          phx_new.enable = true;
          igniter_new.enable = true;
          tailwindcss.enable = true;
          esbuild.enable = true;
        };
      };
    in {
      default = pkgs.mkShell {
        packages = [toolchain];
      };
    });
  };
}
