{ config, lib, pkgs, ... }:

let
  inherit (config.networking) hostName;

  cfg = config.skyflake.storage.glusterfs;

  # locally served by this glusterfs server
  localFileSystems =
    builtins.filter ({ servers, ... }:
      builtins.elem hostName servers
    ) cfg.fileSystems;

  enable = localFileSystems != [];

  mountPointToSystemdUnit = mountPoint:
    with builtins;
    concatStringsSep "-" (
      filter (w: isString w && w != "") (
        split "/" mountPoint
      )
    ) + ".mount";
in
{
  config = lib.mkIf enable {
    services.glusterfs = {
      enable = true;
      useRpcbind = false;
      extraFlags = [ "--logger=syslog" ];
    };

    systemd.services.glusterfs-init = {
      requires = [ "glusterd.service" ];
      after = [ "glusterd.service" "network-online.target" ];
      wantedBy = map ({ mountPoint, ... }:
        mountPointToSystemdUnit mountPoint
      ) localFileSystems;
      before = map ({ mountPoint, ... }:
        mountPointToSystemdUnit mountPoint
      ) localFileSystems;

      path = [ pkgs.glusterfs ];
      script =
        lib.concatMapStringsSep "\n" ({ name, source, servers, ... }:
          let
            otherServers =
              builtins.filter (server:
                server != hostName
              ) servers;
          in ''
            if ! gluster volume get ${name} all >/dev/null ; then
              # If creating a new volume, make all required servers connected.
              ${lib.concatMapStrings (server: ''
                while ! gluster peer probe ${server} ; do
                  echo "Cannot reach glusterd at ${server}, retrying..." >&2
                  sleep 1
                done
              '') otherServers}

              mkdir -p ${source}
              # Now that peer servers are connected, check for volume presence again.
              if ! gluster volume get ${name} all >/dev/null ; then
                gluster volume create ${name} replica ${toString (
                  builtins.length servers
                )} ${lib.concatMapStringsSep " " (server:
                  "${server}:${source}"
                ) servers}
                gluster volume start ${name}
              fi
            fi
          ''
        ) localFileSystems;

      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "30s";
      };
    };

    # Fixup for glusterd dependency
    systemd.services.rpcbind.after = lib.mkIf config.services.glusterfs.useRpcbind [
      "systemd-tmpfiles-setup.service"
    ];
  };
}
