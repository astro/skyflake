{ config, lib, ... }:

let
  inherit (config.skyflake) nodes;

in
{
  options.skyflake.nodes = with lib; mkOption {
    description = ''
      All cluster nodes with their addresses, or at least those who
      run coordination servers (eg. nomad servers, ceph server,
       seaweedfs server ...).
    '';
    default = {};
    type = types.attrsOf (types.submodule {
      options = {
        address = mkOption {
          type = types.str;
          description = ''
            Primary address for traffic between cluster nodes.
          '';
        };
      };
    });
  };

  config = {
    networking.extraHosts = lib.concatMapStrings (name:
      let
        nodeConfig = nodes.${name};
      in ''
        ${nodeConfig.address} ${name}
      ''
    ) (builtins.attrNames nodes);
  };
}
