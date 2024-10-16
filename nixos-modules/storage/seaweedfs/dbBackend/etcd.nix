{ pkgs, config, lib, ... }:
{
  config = lib.mkIf config.skyflake.storage.seaweedfs.filer.db.etcd.enable {
    systemd.tmpfiles.settings."10-etcd"."/var/lib/etcd".d = {
      user = "etcd";
      mode = "0700";
    };

    systemd.services.etcd = {
      description = "etcd key-value store";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      wants = [ "network-online.target" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";

      environment = /* (nixpgs.filterAttrs (n: v: v != null) */ let
        address = config.skyflake.nodes.${config.networking.hostName}.address;
      in  {
        ETCD_NAME = config.networking.hostName;
        #ETCD_DISCOVERY = "true";
        ETCD_DATA_DIR = "/var/lib/etcd";
        ETCD_ADVERTISE_CLIENT_URLS       = "https://[${address}]:2379"; # TODO Make it choose the IP of the device declaratively
        ETCD_LISTEN_CLIENT_URLS          = "https://[${address}]:2379"; # TODO Make it choose the IP of the device declaratively
        ETCD_LISTEN_PEER_URLS            = "https://[${address}]:2380"; # TODO Make it choose the IP of the device declaratively
        ETCD_INITIAL_ADVERTISE_PEER_URLS = "https://[${address}]:2380"; # TODO Make it choose the IP of the device declaratively
        ETCD_CLIENT_CERT_AUTH = "true";
        ETCD_TRUSTED_CA_FILE =       ../../../../example/certs/ca.pem;
        ETCD_CERT_FILE =             ../../../../example/certs/${config.networking.hostName}.pem;
        ETCD_KEY_FILE =              ../../../../example/certs/${config.networking.hostName}-key.pem;
        ETCD_PEER_CLIENT_CERT_AUTH = "true";
        ETCD_PEER_TRUSTED_CA_FILE = ../../../../example/certs/ca.pem;
        ETCD_PEER_CERT_FILE =       ../../../../example/certs/${config.networking.hostName}.pem;
        ETCD_PEER_KEY_FILE =        ../../../../example/certs/${config.networking.hostName}-key.pem;
      #}) // (nixpgs.optionalAttrs (config.services.etcd.discovery == ""){
        ETCD_INITIAL_CLUSTER = lib.concatMapStringsSep ", " (node: "http://[" + (config.skyflake.nodes."${node}").address + "]:2380") (lib.attrNames config.skyflake.nodes);
        # ETCD_INITIAL_CLUSTER = "example1=https://[fec0::1]:2380,example2=https://[fec0::2]:2380,example3=https://[fec0::3]:2380";
        ETCD_INITIAL_CLUSTER_STATE = "new";
        ETCD_INITIAL_CLUSTER_TOKEN = "etcd-cluster";
      #}) // (nixpgs.mapAttrs' (n: v: nixpgs.nameValuePair "ETCD_${n}" v) config.services.etcd.extraConf);
      };
      unitConfig = {
        Documentation = "https://github.com/coreos/etcd";
      };

      serviceConfig = {
        Type = "notify";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = "${pkgs.etcd}/bin/etcd";
        User = "etcd";
        LimitNOFILE = 40000;
      };
    };

    environment.systemPackages = [ pkgs.etcd ];
    /* TODO: add firewall to skyflake.
    networking.firewall = lib.mkIf config.services.etcd.openFirewall {
      allowedTCPPorts = [
        2379 # for client requests
        2380 # for peer communication
      ];
    };
    */
    users.users.etcd = {
      isSystemUser = true;
      group = "etcd";
      description = "Etcd daemon user";
      home = "/var/lib/etcd"; # TODO bring it under a single setting, the state path.
    };
    users.groups.etcd = {};
  };
}