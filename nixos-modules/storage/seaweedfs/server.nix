{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.skyflake.storage.seaweedfs.enable {

    users.users.seaweedfs = {
      isSystemUser = true;
      group = "seaweedfs";
      description = "seaweedfs daemon user";
      home = "/var/lib/seaweedfs"; # TODO bring it under a single setting, the state path.
      createHome = true;
    };
    users.groups.seaweedfs = {};

    # config for the volume deamon of seaweedfs
    systemd.tmpfiles.settings."10-seaweedfs-volume"."/var/lib/seaweedfs/volume".d = {
      user = "seaweedfs";
      group = "seaweedfs";
      mode = "0700";
    };

    # config for the master deamon of seaweedfs
    systemd.tmpfiles.settings."10-seaweedfs-master"."/var/lib/seaweedfs/master".d = {
      user = "seaweedfs";
      group = "seaweedfs";
      mode = "0700";
    };

  systemd.services = lib.mkMerge [ { 
    seaweedfs-master = {
      description = "seaweedfs master service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "etcd.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      wants = [ "network-online.target" "etcd.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      unitConfig = {
        Documentation = "https://github.com/seaweedfs/seaweedfs/wiki";
      };
      serviceConfig = let
        address = config.skyflake.nodes.${config.networking.hostName}.address;
        peers = "${lib.concatMapStrings (x: x + ":9333,") (builtins.catAttrs "address" (builtins.attrValues  config.skyflake.nodes))}";
      in  {
        Type = "simple";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = ''${pkgs.seaweedfs}/bin/weed master -ip=${address} -peers=${peers} -mdir=/var/lib/seaweedfs/master'';
        User = "seaweedfs";
        LimitNOFILE = 40000;
      };
    };

    # config for the filer deamon of seaweedfs
    seaweedfs-filer = {
      description = "seaweedfs filer service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "etcd.service" "seaweedfs-master.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      wants = [ "network-online.target" "etcd.service" "seaweedfs-master.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      unitConfig = {
        Documentation = "https://github.com/seaweedfs/seaweedfs/wiki";
      };
      serviceConfig = let
        address = config.skyflake.nodes.${config.networking.hostName}.address;
      in  {
        Type = "simple";
        Restart = "always";
        RestartSec = "5s";
        # TODO make userdefinable port
        ExecStart = ''${pkgs.seaweedfs}/bin/weed filer ${lib.optionalString config.skyflake.storage.seaweedfs.volumeStorage.encrypt "-encryptVolumeData"} -master=${address}:9333 -port=8888'';
        User = "seaweedfs";
        LimitNOFILE = 40000;
      };
    };

      seaweedfs-volume = {
      description = "seaweedfs volume service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "etcd.service" "seaweedfs-master.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      wants = [ "network-online.target" "etcd.service" "seaweedfs-master.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      unitConfig = {
        Documentation = "https://github.com/seaweedfs/seaweedfs/wiki";
      };
      serviceConfig = let
        address = config.skyflake.nodes.${config.networking.hostName}.address;
      in  {
        Type = "simple";
        Restart = "always";
        RestartSec = "5s";
        # TODO add S3 bucket support in here: https://github.com/seaweedfs/seaweedfs/wiki/Production-Setup#setup-s3-api
        ExecStart = ''${pkgs.seaweedfs}/bin/weed volume -port=8080 -max=5 -ip=${address} -mserver=localhost:9333 -dir=/var/lib/seaweedfs/volume'';
        User = "seaweedfs";
        LimitNOFILE = 40000;
      };
    }; }

    # config for the mount deamon of seaweedfs
      (lib.mapAttrs' (name: value: lib.nameValuePair ("seaweedfs-mount-" + name) { 
        description = "seaweedfs mount service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "etcd.service" "seaweedfs-filer.service" ];
        #  ++ lib.optional config.networking.firewall.enable "firewall.service";
        wants = [ "network-online.target" "etcd.service" "seaweedfs-filer.service" ];
        #  ++ lib.optional config.networking.firewall.enable "firewall.service";
        unitConfig = {
          Documentation = "https://github.com/seaweedfs/seaweedfs/wiki";
        };
        path = with pkgs; [ fuse3 ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "5s";
          #TODO FIX hardcoding of port https://github.com/seaweedfs/seaweedfs/issues/877
          ExecStart = ''${pkgs.seaweedfs}/bin/weed mount -nonempty -filer=localhost:8888 ${lib.optionalString (!builtins.isNull value.replication) "-replication=${builtins.toString value.replication}"} -cacheCapacityMB=${builtins.toString value.cacheCapacity} -chunkSizeLimitMB=${builtins.toString value.chunkSizeLimit} -dirAutoCreate -dir=${builtins.toString name } -filer.path=${value.mountSource}'';
          # TODO FIX mount with root!!!
          User = "root";
          LimitNOFILE = 40000;
        };
      }) config.skyflake.storage.seaweedfs.mounts)
    ];

    environment.systemPackages = with pkgs; [
      seaweedfs # install seaweedfs utils
     ];
    /* TODO: add firewall to skyflake.
    networking.firewall = lib.mkIf config.services.etcd.openFirewall {
      allowedTCPPorts = [
        2379 # for client requests
        2380 # for peer communication
      ];
    };
    */
  };
}