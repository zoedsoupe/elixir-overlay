{
  pkgs,
  beamModule,
}: let
  package = import ./fixture.nix {inherit pkgs;};
  evaluated = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = null;
    modules = [
      beamModule
      {
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;

        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        boot.loader.grub.device = "nodev";
        system.stateVersion = "26.05";

        services.beam.apps = {
          demo = {
            enable = true;
            inherit package;
            command = "bin/server";
            arguments = ["--foreground"];
            preStart = ["${package}/bin/migrate"];
            stateDir = "/zdata/demo";
            environment = {
              PHX_SERVER = "true";
              PORT = "4000";
            };
            environmentFiles = ["/etc/beam/demo.env"];
            extraServiceConfig.RestartSec = 10;
          };

          disabled = {
            enable = false;
            inherit package;
            command = "bin/server";
          };
        };
      }
    ];
  };
  service = evaluated.config.systemd.services.demo;
in
  assert service.serviceConfig.ExecStart == "${package}/bin/server \"--foreground\"";
  assert service.serviceConfig.ExecStartPre == ["${package}/bin/migrate"];
  assert service.serviceConfig.EnvironmentFile == ["/etc/beam/demo.env"];
  assert service.serviceConfig.RestartSec == 10;
  assert service.unitConfig.RequiresMountsFor == ["/zdata/demo"];
  assert service.environment.PHX_SERVER == "true";
  assert service.environment.PORT == "4000";
  assert evaluated.config.users.users.demo.isSystemUser;
  assert evaluated.config.users.users.demo.group == "demo";
  assert pkgs.lib.any (rule: pkgs.lib.hasInfix "/zdata/demo" rule) evaluated.config.systemd.tmpfiles.rules;
  assert !(evaluated.config.systemd.services ? disabled);
    pkgs.runCommand "beam-apps-evaluation-check" {} "touch $out"
