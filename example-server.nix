{ instance }:

{ config, lib, pkgs, ... }:

{
  microvm = {
    vcpu = 2;
    mem = 4096;

    shares = [ {
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } ];
    volumes = [ {
      image = "example${toString instance}-persist.img";
      mountPoint = "/persist";
      size = 20 * 1024;
    } {
      image = "example${toString instance}-ceph.img";
      mountPoint = null;
      size = 20 * 1024;
    } ];
    writableStoreOverlay = "/persist/rw-store";

    interfaces = [ {
      id = "eth0";
      type = "bridge";
      mac = "02:00:00:00:00:0${toString instance}";
      bridge = "virbr0";
    } ];
  };

  fileSystems =
    let
      persist = subdir: {
        device = "/persist/${subdir}";
        fsType = "none";
        options = [ "bind" ];
        depends = [ "/persist" ];
      };
    in {
      "/persist".neededForBoot = lib.mkForce true;
      "/etc" = persist "etc";
      "/var" = persist "var";
      "/home" = persist "home";
    };

  networking.hostName = "example${toString instance}";
  users.users.root.password = "";

  # TODO:
  networking.firewall.enable = false;

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
          addressConfig.Address = "fec0::${toString instance}/64";
        } ];
      };
    };
  };

  skyflake = {
    nodes = builtins.listToAttrs (
      map (instance: {
        name = "example${toString instance}";
        value.address = "fec0::${toString instance}";
      }) [ 1 2 3 ]
    );

    storage.glusterfs.ipv6Default = true;

    storage.ceph = rec {
      fsid = "8364da79-5e03-49ae-82ea-7d936278cb0f";
      monKeyring = example/ceph.mon.keyring;
      adminKeyring = example/ceph.client.admin.keyring;
      osds = [ {
        id = instance;
        fsid = "8e4ae689-5c15-4381-bd75-19de743378e${toString instance}";
        path = "/dev/vdc";
        key = "AQBjQLhj1+JEJxAAIsVIF/Pfw3y+Ie7RlPy7/g==";
      } ];
    };

    nomad = {
      servers = [ "example1" "example2" "example3" ];
      client.meta = {
        example-deployment = "yes";
      };
    };

    users = {
      test = {
        uid = 1000;
        sshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJJTSJdpDh82486uPiMhhyhnci4tScp5uUe7156MBC8 astro"
        ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    tcpdump
  ];
}
