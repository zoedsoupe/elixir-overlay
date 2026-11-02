{
  pkgs,
  name,
  package,
  command,
  tag ? "latest",
  environment ? {},
  contents ? [],
  exposedPorts ? {},
  config ? {},
}:
pkgs.dockerTools.buildLayeredImage {
  inherit name tag;
  contents = [package] ++ contents;
  config =
    {
      Cmd = command;
      Env = pkgs.lib.mapAttrsToList (key: value: "${key}=${toString value}") environment;
      ExposedPorts = exposedPorts;
    }
    // config;
}
