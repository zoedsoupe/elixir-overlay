{
  lib,
  manifests,
  pkgs,
  ...
}: let
  inherit (lib) mapAttrs;
  inherit (manifests) versions latest;

  buildElixir = version: versionData:
    pkgs.stdenv.mkDerivation rec {
      pname = "elixir";
      inherit version;

      src = pkgs.fetchurl {
        inherit (versionData) url sha256;
        name = "elixir-${version}.tar.gz";
      };

      nativeBuildInputs = with pkgs; [makeWrapper];
      buildInputs = with pkgs; [erlang];

      LANG = "C.UTF-8";
      LC_TYPE = "C.UTF-8";

      preBuild = ''
        substituteInPlace Makefile \
          --replace "/usr/local" $out

        if [ -f lib/elixir/scripts/generate_app.escript ]; then
          patchShebangs lib/elixir/scripts/generate_app.escript
        fi
      '';

      postFixup = ''
        substituteInPlace $out/bin/mix \
          --replace "/usr/bin/env elixir" "$out/bin/elixir"

        for f in $out/bin/*; do
          b=$(basename $f)
          if [ "$b" = mix ]; then continue; fi
          wrapProgram $f \
            --prefix PATH ":" "${lib.makeBinPath [pkgs.erlang pkgs.coreutils pkgs.curl pkgs.bash]}"
        done
      '';

      meta = with lib; {
        description = "A dynamic, functional language designed for building maintainable applications";
        longDescription = ''
          Elixir is a dynamic, functional language designed for building
          maintainable and scalable applications. Elixir leverages the Erlang VM,
          known for running low-latency, distributed and fault-tolerant systems.
        '';
        homepage = "https://elixir-lang.org/";
        license = licenses.asl20;
        maintainers = with maintainers; [zoedsoupe];
        platforms = platforms.unix;

        passthru = {
          requiredOtpVersion = {
            min = versionData.minOtpVersion or null;
            max = versionData.maxOtpVersion or null;
          };
        };
      };
    };

  versionPackages = mapAttrs buildElixir versions;
in
  versionPackages
  // {
    latest = versionPackages.${latest};
  }
