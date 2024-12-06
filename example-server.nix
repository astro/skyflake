{ instance }:

{ config, lib, pkgs, ... }:

{
  microvm = {
    vcpu = 2;
    mem = 4096;

    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      } 
    ];
    volumes = [
      {
        image = "example${toString instance}-persist.img";
        mountPoint = "/";
        size = 20 * 1024;
        fsType = "btrfs"; # needed for some seaweedfs optimizations.
      }
      {
        image = "example${toString instance}-ceph.img";
        mountPoint = null;
        size = 20 * 1024;
      }
   ];
   writableStoreOverlay = "/nix/.rw-store";

    interfaces = [ {
      id = "eth0";
      type = "bridge";
      mac = "02:00:00:00:00:0${toString instance}";
      bridge = "virbr0";
    } ];
  };

  networking.hostName = "example${toString instance}";
  users.users.root.password = "";

  networking.firewall.enable = true;

  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network = {
    netdevs = {
      # a bridge to connect microvms
      "br0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br0";
        };
      };
    };

    networks = {
      # uplink
      "00-eth" = {
        matchConfig.MACAddress = (builtins.head config.microvm.interfaces).mac;
        networkConfig.Bridge = "br0";
      };
      # bridge is a dumb switch without addresses on the host
      "01-br0" = {
        matchConfig.Name = "br0";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        addresses = [ {
          Address = "fec0::${toString instance}/64";
        } ];
      };
    };
  };

  skyflake = {
    nodes = builtins.listToAttrs (
      map (instance: {
        name = "example${toString instance}";
        value.address = "[fec0::${toString instance}]";
      }) [ 1 2 3 ]
    );


    storage.seaweedfs = {
      enable = false;
      volumeStorage.encrypt = true;
      # example mount below.
      # mounts."/mnt".mountSource = "/filesystems/1a32bfd9-0cbc-430a-a28a-d9fd862e9ebc";
      filer.db.etcd = {
        enable = true;
        certFile = example/certs/default.pem; 
        keyFile = example/certs/default-key.pem;
        trustedCaFile = example/certs/ca.pem;
      };
    };
    storage.ceph = {
      enable = true;
      fsid = "8364da79-5e03-49ae-82ea-7d936278cb0f";
      monKeyring = example/ceph.mon.keyring;
      adminKeyring = example/ceph.client.admin.keyring;
      osds = [ {
        id = instance;
        fsid = "8e4ae689-5c15-4381-bd75-19de743378e${toString instance}";
        path = "/dev/vdb";
        deviceClass = "ssd";
        keyfile = toString (./example + "/osd.${toString instance}.keyring");
      } ];
      rbdPools.microvms = {
        params = { size = 2; class = "ssd"; };
      };
      cephfs.skyflake.metaParams = { size = 2; class = "ssd"; };
    };

    nomad = {
      servers = builtins.attrNames config.skyflake.nodes;
      client.meta = {
        example-deployment = "yes";
      };
    };

    users = {
      test = {
        uid = 1000;
        sshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJJTSJdpDh82486uPiMhhyhnci4tScp5uUe7156MBC8 astro"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPRRdToCDUupkkwI+crB3fGDwdBIFkDsBHjOImn+qsjg openpgp:0xE8D3D833"
        ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    tcpdump
    nmap
  ];
}