{ config, lib, ... }:

{
  options.skyflake = with lib; {
    users = mkOption {
      description = "Skyflake tenants";
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
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
  } // builtins.mapAttrs (_: _userConfig: {
    isNormalUser = true;
  }) config.skyflake.users;
}
