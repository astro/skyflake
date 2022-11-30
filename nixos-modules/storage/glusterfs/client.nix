{ config, lib, pkgs, ... }:

let
  cfg = config.skyflake.storage.glusterfs;

  getServerAddr = server:
    let
      addr = config.skyflake.nodes.${server}.address;
    in # Check for IPv6 and escape
      if builtins.match ".*:.*" addr != null
      then "[${addr}]"
      else addr;

  localFirst = builtins.sort (a: b: a == config.networking.hostName);

in
{
  environment.systemPackages = [ pkgs.glusterfs ];

  fileSystems = builtins.listToAttrs (
    map ({ mountPoint, name, servers, ... }:
      let
        servers' = localFirst servers;
        firstServer = builtins.head servers';
        otherServers = builtins.tail servers';
      in {
        name = mountPoint;
        value = {
          fsType = "glusterfs";
          device = "${getServerAddr firstServer}:/${name}";
          options = [
            "backup-volfile-servers=${lib.concatMapStringsSep ":" getServerAddr otherServers}"
          ];
        };
      }
    ) cfg.fileSystems
  );
}
