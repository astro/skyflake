{ instance }:

{ config, ... }:

{
  microvm = {
    mem = 2048;

    shares = [ {
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } ];
    volumes = [ {
      image = "nix-store-overlay.img";
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

  skyflake.nomad = {
    servers = [ "example1" ];
  };

  skyflake.users = {
    test = {
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJJTSJdpDh82486uPiMhhyhnci4tScp5uUe7156MBC8 astro"
      ];
    };
  };
}
