{
  pkgs,
  mkBeamImage,
}: let
  package = import ./fixture.nix {inherit pkgs;};
in
  mkBeamImage {
    inherit pkgs package;
    name = "beam-runtime-fixture";
    command = ["${package}/bin/server"];
    environment = {
      PHX_SERVER = "true";
      PORT = 4000;
    };
    contents = [pkgs.cacert];
    exposedPorts = {
      "4000/tcp" = {};
    };
  }
