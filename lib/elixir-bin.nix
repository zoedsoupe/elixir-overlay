{
  lib,
  manifests,
  pkgs,
  ...
}: let
  inherit (lib) mapAttrs optionalString;
  inherit (manifests) versions latest;

  buildElixir = version: versionData:
    pkgs.stdenv.mkDerivation rec {
      pname = "elixir";
      inherit version;

      src = pkgs.fetchurl {
        inherit (versionData) url sha256;
      };

      nativeBuildInputs = with pkgs; [
        erlang
        makeWrapper
      ];

      env = {
        LANG = "C.UTF-8";
        LC_ALL = "C.UTF-8";
      };

      configurePhase = "true";

      buildPhase = ''
        runHook preBuild
        make compile
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        make install PREFIX=$out

        for bin in $out/bin/*; do
          if [ -f "$bin" ] && [ -x "$bin" ]; then
            wrapProgram "$bin" \
              --prefix PATH : ${pkgs.erlang}/bin \
              --set LANG "C.UTF-8" \
              --set LC_ALL "C.UTF-8"
          fi
        done

        runHook postInstall
      '';

      doCheck = true;
      checkPhase = ''
        runHook preCheck
        make test
        runHook postCheck
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
        maintainers = with maintainers; [];
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
