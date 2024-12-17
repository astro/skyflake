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

    # https://developer.hashicorp.com/nomad/docs/install/production/requirements#ports-used
    networking.firewall.allowedUDPPorts = [
      4648 #Serf WAN
    ];
    networking.firewall.allowedTCPPorts = [
      4646 # TODO Fix firewall with option HTTP API
      4648 # Serf WAN
    ];

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
      default = builtins.attrNames config.skyflake.nodes;
    };

    client.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Should the nomad-agent run in client mode to run tasks?
      '';
    };

    client.meta = mkOption {
      type = with types; attrsOf str;
      default = {};
    };
  };

  config = {
    services.nomad = {
      enable = true;
      package = pkgs.nomadPin.nomad_1_6; # nomad 1.6 is the newest version under an foss license.
      dropPrivileges = false;
      enableDocker = false;

      settings = rec {
        inherit (cfg) datacenter;
        plugin.raw_exec.config = {
          enabled = true;
          # unfortunately, this feature removes the ability to use /dev/kvm
          no_cgroups = true;
        };

        server = {
          enabled = cfg.server.enable;
          bootstrap_expect = builtins.length cfg.servers; # why not this? Why this weird formular? (${NOMAD_SERVERS} + 2) / 2 ?
          server_join.retry_join = cfg.servers;
        };
        advertise = let
          address = config.skyflake.nodes.${config.networking.hostName}.address;
        in  {
            serf = "${address}:4648";
        };
        client = {
          enabled = cfg.client.enable;
          inherit (cfg.client) meta;
          inherit (server) server_join;
        };
      };
    };
    systemd.services.nomad = {
      requires = [ "local-fs.target" "remote-fs.target" ];
      serviceConfig.ExecStop = "${config.services.nomad.package}/bin/nomad node drain -enable -self";
    };

    environment.systemPackages = with pkgs; [
      # alternatives to the nomad web ui
      wander damon
      # needed for microvms
      virtiofsd
      jq kmod e2fsprogs
    ];
  };
}
