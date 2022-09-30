{ config, lib, pkgs, ... }:
let
  cfg = config.skyflake.nomad;
in
{
  options.skyflake.nomad = with lib; {
    datacenter = mkOption {
      type = types.str;
      default = "sky0";
    };

    server.enable = mkOption {
      type = types.bool;
      default = builtins.elem config.networking.hostName cfg.servers;
      description = ''
        Should the nomad-agent run in server mode?

        Defaults to true if `networking.hostName` is in `skyflake.nomad.servers`
      '';
    };

    servers = mkOption {
      type = with types; listOf str;
    };
  };
  
  config.services.nomad = {
    enable = true;
    package = pkgs.nomad_1_3;
    dropPrivileges = false;
    enableDocker = false;

    settings = rec {
      inherit (cfg) datacenter;
      plugin.raw_exec.config.enabled = true;

      server = {
        enabled = true;
        bootstrap_expect = (builtins.length cfg.servers + 2) / 2;
        server_join.retry_join = cfg.servers;
      };
      client = {
        enabled = true;
        inherit (server) server_join;
      };
    };
  };
}
