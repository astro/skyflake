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
      image = "nix-store-overlay${toString instance}.img";
      mountPoint = config.microvm.writableStoreOverlay;
      size = 20 * 1024;
    } ];
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
  networking.extraHosts = lib.concatMapStrings (instance: ''
    fec0::${toString instance} example${toString instance}
  '') [ 1 2 3 ];

  skyflake.nomad = {
    servers = [ "example1" "example2" "example3" ];
  };

  skyflake.users = {
    test = {
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJJTSJdpDh82486uPiMhhyhnci4tScp5uUe7156MBC8 astro"
      ];
    };
  };
}
