{ instance }:

{ config, lib, ... }:

{
  microvm = {
    mem = 2048;

    shares = [ {
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } ];
    volumes = [ {
      image = "example1${toString instance}.img";
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
  systemd.network.networks = {
    "00-eth" = {
      matchConfig.MACAddress = (builtins.head config.microvm.interfaces).mac;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      addresses = [ {
        addressConfig.Address = "fec0::${toString instance}/64";
      } ];
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
        sshKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJJTSJdpDh82486uPiMhhyhnci4tScp5uUe7156MBC8 astro"
        ];
      };
    };
  };
}
