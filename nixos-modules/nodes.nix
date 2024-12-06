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

      Should be always a majority, i.e.: an uneven number,
      commonly 3 or 5 to have a redundancy of 1 or 2 or
      mathmatically: 2(REDUNDANCY)+1=NEEDED_SERVERS.
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
