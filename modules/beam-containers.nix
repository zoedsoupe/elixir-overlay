{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  containerType = types.submodule ({name, ...}: {
    options = {
      enable = mkEnableOption "this BEAM OCI container";

      image = mkOption {
        type = types.str;
        example = "ghcr.io/example/app:1.2.3";
        description = ''
          OCI image reference. Select an explicit release tag or SHA-256 digest;
          an unversioned image and the latest tag are refused.
        '';
      };

      uid = mkOption {
        type = types.int;
        example = 33333;
        description = "Stable host UID shared by the service user and container.";
      };

      gid = mkOption {
        type = types.int;
        example = 33333;
        description = "Stable host GID shared by the service group and container.";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/${name}";
        defaultText = lib.literalExpression ''"/var/lib/''${name}"'';
        description = "Host directory mounted at /data.";
      };

      requiredMounts = mkOption {
        type = types.listOf types.path;
        default = [];
        example = ["/zdata"];
        description = ''
          Paths that must already be mountpoints before the service starts.
          No mounts or ownership changes are performed.
        '';
      };

      volumes = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["/var/lib/app/backups:/backups"];
        description = "Additional container volumes. The dataDir volume is managed separately.";
      };

      port = mkOption {
        type = types.nullOr types.port;
        default = null;
        example = 4000;
        description = ''
          Container and host port to publish. Null leaves all ports unpublished.
          Use extraContainerConfig.ports for mappings with different host and
          container ports.
        '';
      };

      listenAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = "Host address on which port is published.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Non-secret container environment variables.";
      };

      environmentFiles = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["/run/secrets/app.env"];
        description = ''
          Host-side environment files containing runtime secrets. Use absolute
          path strings so secret files are not copied into the Nix store.
        '';
      };

      entrypoint = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/app/bin/server";
        description = "Container entrypoint. Null preserves the image default.";
      };

      cmd = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Arguments passed to the container entrypoint.";
      };

      extraContainerConfig = mkOption {
        type = types.attrs;
        default = {};
        description = ''
          Additional virtualisation.oci-containers container settings, merged last.
        '';
      };

      extraServiceConfig = mkOption {
        type = types.attrs;
        default = {};
        description = "Additional systemd serviceConfig settings.";
      };
    };
  });

  enabled = lib.filterAttrs (_: container: container.enable) config.services.beam.containers;

  imagePinned = image: let
    imageRef = builtins.head (lib.splitString "@" image);
    imageName = lib.last (lib.splitString "/" imageRef);
    imageHasTag = lib.hasInfix ":" imageName && !(lib.hasSuffix ":latest" imageName);
    imageHasDigest = (builtins.match ".*@sha256:[0-9a-fA-F]{64}$" image) != null;
  in
    imageHasDigest || imageHasTag;

  storagePreStart = container:
    lib.concatStringsSep "\n" (map (path: ''
        if ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg (toString path)}; then
          echo "required mount is not available: ${toString path}" >&2
          exit 1
        fi
      '')
      container.requiredMounts);

  containerConfig = name: container:
    {
      inherit (container) image environmentFiles entrypoint cmd;
      serviceName = name;
      user = "${toString container.uid}:${toString container.gid}";
      workdir = "/data";
      environment =
        {
          HOME = "/data";
        }
        // container.environment;
      volumes = ["${container.dataDir}:/data"] ++ container.volumes;
      ports =
        lib.optional (container.port != null)
        "${container.listenAddress}:${toString container.port}:${toString container.port}";
      log-driver = "journald";
      pull = "missing";
    }
    // container.extraContainerConfig;
in {
  options.services.beam.containers = mkOption {
    type = types.attrsOf containerType;
    default = {};
    description = "BEAM OCI images to run as Docker containers, keyed by application name.";
  };

  config = lib.mkMerge [
    {
      assertions =
      lib.mapAttrsToList (name: container: {
        assertion = imagePinned container.image;
        message = "services.beam.containers.${name}.image must select an explicit tag or SHA-256 digest, not latest.";
      })
      enabled;

    users.users = lib.mapAttrs' (name: container:
      lib.nameValuePair name {
        isSystemUser = true;
        group = name;
        uid = container.uid;
        home = container.dataDir;
        description = "${name} service user";
      })
    enabled;

    users.groups = lib.mapAttrs' (name: container:
      lib.nameValuePair name {gid = container.gid;})
    enabled;

    systemd.tmpfiles.rules =
      lib.mapAttrsToList (name: container: "d '${container.dataDir}' 0700 ${name} ${name} -")
      enabled;

    virtualisation.oci-containers.containers = lib.mapAttrs containerConfig enabled;

    systemd.services = lib.mapAttrs' (name: container: let
      serviceName = (containerConfig name container).serviceName;
    in
      lib.nameValuePair serviceName ({
          unitConfig.RequiresMountsFor = lib.unique ([container.dataDir] ++ container.requiredMounts);
          serviceConfig = container.extraServiceConfig;
        }
        // lib.optionalAttrs (container.requiredMounts != []) {
          preStart = storagePreStart container;
        }))
      enabled;
    }
    (mkIf (enabled != {}) {
      virtualisation.docker.enable = lib.mkDefault true;
      virtualisation.oci-containers.backend = "docker";
    })
  ];
}
