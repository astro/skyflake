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
            type = with types; nullOr str;
            description = ''
              User home directory
            '';
            default = null;
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
    inherit uid;
    isNormalUser = true;
    createHome = true;
    home = lib.mkIf (home != null) home;
  }) config.skyflake.users;
}
