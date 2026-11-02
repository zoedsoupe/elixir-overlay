{
  config,
  lib,
  utils,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  appType = types.submodule ({name, ...}: {
    options = {
      enable = mkEnableOption "this BEAM application";

      package = mkOption {
        type = types.package;
        description = "The release package to run.";
      };

      command = mkOption {
        type = types.str;
        example = "bin/server";
        description = "Start executable, absolute or relative to the release package.";
      };

      arguments = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["start"];
        description = "Arguments passed to the start executable.";
      };

      preStart = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["/nix/store/...-my-app/bin/migrate"];
        description = "Commands executed before the start executable.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Non-secret environment variables.";
      };

      environmentFiles = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "Environment files containing runtime secrets.";
      };

      stateDir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Optional external writable state directory.";
      };

      extraServiceConfig = mkOption {
        type = types.attrs;
        default = {};
        description = "Additional systemd service settings, merged last.";
      };
    };
  });

  enabled = lib.filterAttrs (_: app: app.enable) config.services.beam.apps;
  executable = package: command:
    if lib.hasPrefix "/" command
    then command
    else "${package}/${command}";
in {
  options.services.beam.apps = mkOption {
    type = types.attrsOf appType;
    default = {};
    description = "BEAM releases to run as systemd services, keyed by application name.";
  };

  config = mkIf (enabled != {}) {
    users.users = lib.mapAttrs' (name: app:
      lib.nameValuePair name {
        isSystemUser = true;
        group = name;
        home =
          if app.stateDir != null
          then app.stateDir
          else "/var/lib/${name}";
        description = "${name} service user";
      })
    enabled;

    users.groups = lib.mapAttrs' (name: _: lib.nameValuePair name {}) enabled;

    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (name: app:
      lib.optional (app.stateDir != null) "d '${app.stateDir}' 0700 ${name} ${name} -")
    enabled);

    systemd.services = lib.mapAttrs' (name: app:
      lib.nameValuePair name {
        description = "${name} (BEAM release)";
        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];
        unitConfig.RequiresMountsFor = lib.optional (app.stateDir != null) app.stateDir;

        environment =
          {
            LANG = "C.UTF-8";
          }
          // app.environment;

        serviceConfig =
          {
            Type = "exec";
            User = name;
            Group = name;
            StateDirectory = name;
            WorkingDirectory =
              if app.stateDir != null
              then app.stateDir
              else "/var/lib/${name}";
            EnvironmentFile = app.environmentFiles;
            ExecStart =
              executable app.package app.command
              + lib.optionalString (app.arguments != []) " ${utils.escapeSystemdExecArgs app.arguments}";
            ExecStartPre = app.preStart;
            Restart = "on-failure";
            RestartSec = 5;
            KillSignal = "SIGTERM";
            TimeoutStopSec = 30;
            LimitNOFILE = 65536;

            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            ReadWritePaths = lib.optional (app.stateDir != null) app.stateDir;
          }
          // app.extraServiceConfig;
      })
    enabled;
  };
}
