{ lib, manifests, pkgs, ... }:

let
  inherit (lib) mapAttrs;
  inherit (manifests) versions latest;

  # Build a specific Elixir version
  buildElixir = version: versionData:
    pkgs.stdenv.mkDerivation {
      pname = "elixir";
      version = version;

      src = pkgs.fetchurl {
        inherit (versionData) url sha256;
      };

      nativeBuildInputs = with pkgs; [
        erlang
        makeWrapper
      ];

      # For now, we'll use a simple build process
      # This would need to be refined based on how Elixir is actually built
      buildPhase = ''
        make compile
      '';

      installPhase = ''
        mkdir -p $out
        cp -r . $out/
        
        # Wrap binaries to ensure they find Erlang
        for bin in $out/bin/*; do
          if [ -f "$bin" ]; then
            wrapProgram "$bin" \
              --prefix PATH : ${pkgs.erlang}/bin
          fi
        done
      '';

      meta = with lib; {
        description = "A dynamic, functional language designed for building maintainable applications";
        homepage = "https://elixir-lang.org/";
        license = licenses.asl20;
        maintainers = with maintainers; [ ];
        platforms = platforms.unix;
      };
    };

  # Create derivations for all versions
  versionPackages = mapAttrs buildElixir versions;

in versionPackages // {
  # Convenience alias for latest version
  latest = versionPackages.${latest};
}