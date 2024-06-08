{ lib, ... }:
{
  options.skyflake.storage.seaweedfs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        enable seaweedfs as the storage backend.
      '';
    };
    seaweedfsMount = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          mountPoint = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
          };
        };
      });
    };
    #master = {
    #  serverIP = lib.mkOption {
    #    type = lib.str;
    #    description = ''
    #      IP of this node.
    #    '';
    #  };
    #  listenIPs = lib.mkOption {
    #    type = lib.listOf lib.str;
    #    description = ''
    #      IP of all the master servers.
    #      Can be the same as storage nodes.
    #    '';
    #  };
    #};
    volumeStorage = {
      encrypt = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          enable encryption on volume store.
        '';
      };
      #datacenter = {
      #  type = lib.str;
      #  description = ''
      #    The datacenter location of the node.
      #  '';
      #};
      #rack = {
      #  type = lib.str;
      #  description = ''
      #    The rack location of the node.
      #  '';
      #};
      #serverIP = lib.mkOption {
      #  type = lib.listOf lib.str;
      #  description = ''
      #    IP of this node.
      #  '';
      #};
      #listenIPs = lib.mkOption {
      #  type = lib.listOf lib.str;
      #  description = ''
      #    IPs of all the nodes that should store the actual data but not metadata.
      #    Can be the same as DB nodes.
      #  '';
      #};
    };
    filer.db = {
      etcd = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Use to enable Kubernetes etcd database as a backend for seaweedfs.
          '';
        };
        
      };
    };
  };
}