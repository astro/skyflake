{ pkgs, config, lib, ... }:
{
  config = lib.mkIf (builtins.all (x: x == true) [ config.skyflake.storage.seaweedfs.filer.db.etcd.enable config.skyflake.storage.seaweedfs.enable ]) {
    systemd.tmpfiles.settings."10-etcd"."/var/lib/etcd".d = {
      user = "etcd";
      mode = "0700";
    };

    systemd.services."etcd" = {
      description = "etcd key-value store";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "network.target" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";
      wants = [ "network-online.target" ];
      #  ++ lib.optional config.networking.firewall.enable "firewall.service";

      environment = /* (nixpgs.filterAttrs (n: v: v != null) */ let
        address = config.skyflake.nodes.${config.networking.hostName}.address;
      in  {
        ETCD_NAME = config.networking.hostName;
        ETCD_DATA_DIR = "/var/lib/etcd";
        ETCD_ADVERTISE_CLIENT_URLS       = "https://${address}:2379";
        ETCD_LISTEN_CLIENT_URLS          = "https://${address}:2379";
        ETCD_LISTEN_PEER_URLS            = "https://${address}:2380";
        ETCD_INITIAL_ADVERTISE_PEER_URLS = "https://${address}:2380";
        ETCD_CLIENT_CERT_AUTH = "true";
        ETCD_TRUSTED_CA_FILE =       ../../../../example/certs/ca.pem;
        ETCD_CERT_FILE =             ../../../../example/certs/${config.networking.hostName}.pem;
        ETCD_KEY_FILE =              ../../../../example/certs/${config.networking.hostName}-key.pem;
        ETCD_PEER_CLIENT_CERT_AUTH = "true";
        ETCD_PEER_TRUSTED_CA_FILE = ../../../../example/certs/ca.pem;
        ETCD_PEER_CERT_FILE =       ../../../../example/certs/${config.networking.hostName}.pem;
        ETCD_PEER_KEY_FILE =        ../../../../example/certs/${config.networking.hostName}-key.pem;
        ETCD_INITIAL_CLUSTER = "${lib.concatMapStringsSep "," (node: "${node}=https://" + (config.skyflake.nodes."${node}").address + ":2380") (builtins.attrNames config.skyflake.nodes)}";
        ETCD_INITIAL_CLUSTER_STATE = "new";
        ETCD_INITIAL_CLUSTER_TOKEN = "etcd-cluster";
      };
      unitConfig = {
        Documentation = "https://etcd.io/docs/v3.5/";
      };

      serviceConfig = {
        Type = "notify";
        Restart = "always";
        RestartSec = "5s";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 2"; # TODO fix workaround, so that it doesnt stop on first start because it cant bind.
        ExecStart = "${pkgs.etcd}/bin/etcd";
        User = "etcd";
        LimitNOFILE = 40000;
      };
    };

    environment.etc.seaweedfs-filer = { 
      text = ''
        [etcd]
        enabled = true
          servers = "${lib.concatMapStringsSep "," (node: (config.skyflake.nodes."${node}").address + ":2379") (builtins.attrNames config.skyflake.nodes)}"
        # username = "seaweedfs"
        # password = ""
        key_prefix = "seaweedfs."
        timeout = "3s"
        # Set the CA certificate path
        tls_ca_file =         "${../../../../example/certs/ca.pem}"
        # Set the client certificate path
        tls_client_crt_file = "${../../../../example/certs/${config.networking.hostName}.pem}"
        # Set the client private key path
        tls_client_key_file = "${../../../../example/certs/${config.networking.hostName}-key.pem}"
      '';
      target = "./seaweedfs/filer.toml";
      user = "seaweedfs";
      mode = "0440";
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