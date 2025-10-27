{
  lib,
  manifests,
  pkgs,
  erlang ? null,
  ...
}: let
  inherit (lib) mapAttrs;
  inherit (manifests) versions latest;

  # Select compatible Erlang version based on maxOtpVersion constraint
  # Prioritizes using the highest compatible OTP version available
  selectErlang = versionData:
    if erlang != null
    then erlang
    else let
      maxOtp = lib.strings.toInt versionData.maxOtpVersion;
    in
      # Select the highest available OTP version that doesn't exceed maxOtp
      if maxOtp >= 28
      then pkgs.erlang_28
      else if maxOtp >= 27
      then pkgs.erlang_27
      else if maxOtp >= 26
      then pkgs.erlang_26
      else pkgs.erlang_26; # Fallback to 26 for older Elixir versions

  buildElixir = version: versionData: let
    selectedErlang = selectErlang versionData;
  in
    pkgs.stdenv.mkDerivation rec {
      pname = "elixir";
      inherit version;

      src = pkgs.fetchurl {
        inherit (versionData) url sha256;
        name = "elixir-${version}.tar.gz";
      };

      nativeBuildInputs = with pkgs; [makeWrapper];
      buildInputs = [selectedErlang];

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
          --replace "/usr/bin/env elixir" "${pkgs.coreutils}/bin/env $out/bin/elixir"

        for f in $out/bin/*; do
          b=$(basename $f)
          if [ "$b" = mix ]; then continue; fi
          wrapProgram $f \
            --prefix PATH ":" "${lib.makeBinPath [selectedErlang pkgs.coreutils pkgs.curl pkgs.bash]}"
        done
      '';

      passthru = {
        requiredOtpVersion = {
          min = versionData.minOtpVersion or null;
          max = versionData.maxOtpVersion or null;
        };
        erlang = selectedErlang;
        otpVersion = selectedErlang.version or "unknown";
      };

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
      };
    };

  versionPackages = mapAttrs buildElixir versions;
in
  versionPackages
  // {
    latest = versionPackages.${latest};
  }
