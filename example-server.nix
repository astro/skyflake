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
      image = "example${toString instance}.img";
      mountPoint = "/persist";
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
      "vmbr0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "vmbr0";
        };
        extraConfig = ''
          [Bridge]
          VLANFiltering=on
          DefaultPVID=none
        '';
      };
      # a tunnel to join the bridges across cluster nodes
      "tun0" = {
        netdevConfig = {
          Kind = "vxlan";
          Name = "tun0";
          MTUBytes = "1522";
        };
        vxlanConfig = {
          VNI = 1;
          Group = "ff02::bbbb";
        };
      };
    };

    networks = {
      # uplink
      "00-eth" = {
        matchConfig.MACAddress = (builtins.head config.microvm.interfaces).mac;
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
          # create the tunnel over this ethernet
          VXLAN = "tun0";
        };
        addresses = [ {
          addressConfig.Address = "fec0::${toString instance}/64";
        } ];
      };
      # bridge is a dumb switch without addresses on the host
      "01-vmbr0" = {
        matchConfig.Name = "vmbr0";
        linkConfig.MTUBytes = "1522";
        networkConfig = {
          DHCP = "no";
          # LinkLocalAddressing = "no";
        };
      };
      # expand bridge over tunnel
      "02-tun0" = {
        matchConfig.Name = "tun0";
        # not working?
        linkConfig.MTUBytes = "1522";
        networkConfig.Bridge = "vmbr0";
        extraConfig = ''
          [BridgeVLAN]
          VLAN=1-4094
        '';
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

    nomad = {
      servers = [ "example1" "example2" "example3" ];
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
