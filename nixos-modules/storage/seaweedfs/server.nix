{ config, lib, pkgs, ... }:
{
  config = lib.mkIf config.skyflake.storage.seaweedfs.filer.db.etcd.enable {

    users.users.seaweedfs = {
      isSystemUser = true;
      group = "seaweedfs";
      description = "seaweedfs daemon user";
      home = "/var/lib/seaweedfs"; # TODO bring it under a single setting, the state path.
      createHome = true;
    };
    users.groups.seaweedfs = {};

    # config for the master deamon of seaweedfs
    systemd.tmpfiles.settings."10-seaweedfs-master"."/var/lib/seaweedfs/master".d = {
      user = "seaweedfs";
      mode = "0700";
    };
    systemd.services.seaweedfs-master = {
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
        address = builtins.elemAt (lib.splitString "/" (lib.head config.systemd.network.networks."01-br0".addresses).Address) 0;
      in  {
        Type = "notify";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = ''${pkgs.seaweedfs}/bin/weed master -ip=[${address}] -mdir=/var/lib/seaweedfs/master'';
        User = "seaweedfs";
        LimitNOFILE = 40000;
      };
    };

    # config for the filer deamon of seaweedfs
    systemd.tmpfiles.settings."10-seaweedfs-filer"."/var/lib/seaweedfs/filer".d = {
      user = "seaweedfs";
      mode = "0700";
    };
    systemd.services.seaweedfs-filer = {
      description = "seaweedfs filer service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "etcd.service" "seaweedfs-master.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      wants = [ "network-online.target" "etcd.service" "seaweedfs-master.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      unitConfig = {
        Documentation = "https://github.com/seaweedfs/seaweedfs/wiki";
      };
      serviceConfig = {
        Type = "notify";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = ''${pkgs.seaweedfs}/bin/weed filer -master.port=9333 -volume.port=8080 -dir=/var/lib/seaweedfs/filer'';
        User = "seaweedfs";
        LimitNOFILE = 40000;
      };
    };
    environment.etc.seaweedfs-filer = { 
      text = ''
        [etcd]
        enabled = true
        servers = "example1=https://[fec0::1]:2380,example2=https://[fec0::2]:2380,example3=https://[fec0::3]:2380"
        # username = "seaweedfs"
        # password = ""
        key_prefix = "seaweedfs."
        timeout = "3s"
        # Set the CA certificate path
        tls_ca_file=""
        # Set the client certificate path
        tls_client_crt_file=""
        # Set the client private key path
        tls_client_key_file=""      '';
      target = "./seaweedfs/filer.toml";
      mode = "0440";
    };

    # config for the volume deamon of seaweedfs
    systemd.tmpfiles.settings."10-seaweedfs-volume"."/var/lib/seaweedfs/volume".d = {
      user = "seaweedfs";
      mode = "0700";
    };
    systemd.services.seaweedfs-volume = {
      description = "seaweedfs volume service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "etcd.service" "seaweedfs-master.service" "seaweedfs-filer.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      wants = [ "network-online.target" "etcd.service" "seaweedfs-master.service" "seaweedfs-filer.service" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      unitConfig = {
        Documentation = "https://github.com/seaweedfs/seaweedfs/wiki";
      };
      serviceConfig = let
        address = builtins.elemAt (lib.splitString "/" (lib.head config.systemd.network.networks."01-br0".addresses).Address) 0;
      in  {
        Type = "notify";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = ''${pkgs.seaweedfs}/bin/weed volume -port=8080 -max=5 -ip=${address} -mserver=localhost:9333 -dir=/var/lib/seaweedfs/volume'';
        User = "seaweedfs";
        LimitNOFILE = 40000;
      };
    };

    environment.systemPackages = [ pkgs.seaweedfs ];
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