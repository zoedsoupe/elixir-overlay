{
  pkgs,
  beamContainersModule,
}: let
  evaluated = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = null;
    modules = [
      beamContainersModule
      {
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;

        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        boot.loader.grub.device = "nodev";
        system.stateVersion = "26.05";

        services.beam.containers = {
          demo = {
            enable = true;
            image = "ghcr.io/example/demo:1.2.3";
            uid = 33333;
            gid = 33334;
            dataDir = "/zdata/demo";
            requiredMounts = ["/zdata"];
            volumes = ["/zdata/demo-backups:/backups"];
            port = 4000;
            listenAddress = "100.64.0.2";
            environment.PHX_SERVER = "true";
            environmentFiles = ["/etc/beam/demo.env"];
            entrypoint = "/app/bin/server";
            cmd = ["start"];
            extraContainerConfig.autoStart = false;
            extraServiceConfig.RestartSec = 10;
          };

          defaults = {
            enable = true;
            image = "ghcr.io/example/defaults@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            uid = 33335;
            gid = 33336;
          };

          disabled = {
            enable = false;
            image = "ghcr.io/example/disabled:latest";
            uid = 33337;
            gid = 33338;
          };
        };
      }
    ];
  };

  invalid = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = null;
    modules = [
      beamContainersModule
      {
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        boot.loader.grub.device = "nodev";
        system.stateVersion = "26.05";
        services.beam.containers.invalid = {
          enable = true;
          image = "ghcr.io/example/demo:latest";
          uid = 33339;
          gid = 33340;
        };
      }
    ];
  };

  config = evaluated.config;
  container = config.virtualisation.oci-containers.containers.demo;
  service = config.systemd.services.demo;
in
  assert config.virtualisation.oci-containers.backend == "docker";
  assert config.virtualisation.docker.enable;
  assert container.serviceName == "demo";
  assert container.image == "ghcr.io/example/demo:1.2.3";
  assert container.user == "33333:33334";
  assert container.workdir == "/data";
  assert container.environment.HOME == "/data";
  assert container.environment.PHX_SERVER == "true";
  assert container.environmentFiles == ["/etc/beam/demo.env"];
  assert container.entrypoint == "/app/bin/server";
  assert container.cmd == ["start"];
  assert container.volumes == ["/zdata/demo:/data" "/zdata/demo-backups:/backups"];
  assert container.ports == ["100.64.0.2:4000:4000"];
  assert container.log-driver == "journald";
  assert container.pull == "missing";
  assert !container.autoStart;
  assert config.users.users.demo.uid == 33333;
  assert config.users.groups.demo.gid == 33334;
  assert pkgs.lib.any (rule: pkgs.lib.hasInfix "/zdata/demo" rule) config.systemd.tmpfiles.rules;
  assert service.unitConfig.RequiresMountsFor == ["/zdata/demo" "/zdata"];
  assert service.serviceConfig.RestartSec == 10;
  assert pkgs.lib.hasInfix "mountpoint -q /zdata" service.preStart;
  assert config.virtualisation.oci-containers.containers.defaults.volumes == ["/var/lib/defaults:/data"];
  assert config.virtualisation.oci-containers.containers.defaults.ports == [];
  assert !(config.virtualisation.oci-containers.containers ? disabled);
  assert !(config.users.users ? disabled);
  assert pkgs.lib.any (assertion: !assertion.assertion && pkgs.lib.hasInfix "explicit tag" assertion.message) invalid.config.assertions;
    pkgs.runCommand "beam-containers-evaluation-check" {} "touch $out"
