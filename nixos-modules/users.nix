{ config, lib, ... }:

{
  options.skyflake = with lib; {
    users = mkOption {
      description = "Skyflake tenants";
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          uid = mkOption {
            type = types.int;
            description = ''
              Users should have a distinct static user id across cluster nodes.
            '';
          };
          sshKeys = mkOption {
            default = [];
            type = with types; listOf str;
          };
        };
      });
    };
  };

  config.users.users = {
    microvm = {
      isSystemUser = true;
      group = "kvm";
      # # allow access to zvol
      # extraGroups = [ "disk" ];
    };
  } // builtins.mapAttrs (_: { uid, ... }: {
    inherit uid;
    isNormalUser = true;
  }) config.skyflake.users;
}
