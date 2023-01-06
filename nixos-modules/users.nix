{ config, lib, ... }:

{
  options.skyflake = with lib; {
    users = mkOption {
      description = "Skyflake tenants";
      default = {};
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          uid = mkOption {
            type = types.int;
            description = ''
              Users should have a distinct static user id across cluster nodes.
            '';
          };

          home = mkOption {
            type = types.str;
            description = ''
              User home directory
            '';
            default = "${config.skyflake.storage.ceph.cephfs.cephfs.mountPoint}/home/${name}";
          };

          sshKeys = mkOption {
            default = [];
            type = with types; listOf str;
          };
        };
      }));
    };
  };

  config.users.users = {
    microvm = {
      isSystemUser = true;
      group = "kvm";
      # # allow access to zvol
      # extraGroups = [ "disk" ];
    };
  } // builtins.mapAttrs (_: { uid, home, ... }: {
    inherit uid home;
    isNormalUser = true;
    createHome = true;
  }) config.skyflake.users;
}
