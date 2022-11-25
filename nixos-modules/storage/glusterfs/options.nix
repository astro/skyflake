{ config, lib, ... }:

{
  options.skyflake.storage.glusterfs = with lib; {
    fileSystems = mkOption {
      description = ''
        List of glusterfs filesystems shared in the cluster.
      '';
      default = [ {
        mountPoint = "/storage/glusterfs";
        source = "/var/glusterfs";
      } ];
      type = types.listOf (types.submodule (submoduleArgs: {
        options = {
          mountPoint = mkOption {
            type = types.str;
            description = ''
              Where to mount the filesystem on all nodes.
            '';
          };

          name = mkOption {
            type = types.str;
            default = baseNameOf submoduleArgs.config.mountPoint;
            description = ''
              glusterfs handle
            '';
          };

          source = mkOption {
            type = types.str;
            description = ''
              Backing directory path on glusterfs servers.

              This setting can be different between servers.
            '';
          };

          servers = mkOption {
            type = with types; listOf str;
            default = builtins.attrNames config.skyflake.nodes;
            description = ''
              glusterfs servers that host this filesystem.

              This defaults to all nodes in the cluster which is fine
              for very small clusters.
            '';
          };
        };
      }));
    };

    ipv6Default = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Configure glusterd to listen on IPv6 [::] by default.
      '';
    };

    pingTimeout = mkOption {
      type = types.int;
      default = 10;
      description = ''
        Sets gluster volume network.ping-timeout on creation
      '';
    };
  };

  config = {
    nixpkgs.config = lib.mkIf config.skyflake.storage.glusterfs.ipv6Default {
      packageOverrides = pkgs: {
        glusterfs = pkgs.glusterfs.overrideAttrs (attrs: {
          configureFlags = attrs.configureFlags ++ [
            "--with-ipv6-default"
          ];
          # seems to break with IPv6
          doInstallCheck = false;
        });
      };
    };
  };

}
