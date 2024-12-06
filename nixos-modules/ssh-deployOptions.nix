{ config, lib, ... }:
{
  options.skyflake = with lib; {
    deploy = {
      datacenters = mkOption {
        type = with types; listOf str;
        default = [ config.skyflake.nomad.datacenter ];
        description = ''
          List of datacenters to deploy to.
        '';
      };

      binaryCachePath = mkOption {
        type = types.str;
        default = "/var/lib/skyflake/binary-cache";
        description = ''
          Directory which is mounted on all nodes that will be used to
          share the /nix/store with MicroVMs.
        '';
      };

      sharedGcrootsPath = mkOption {
        type = types.str;
        default = "/nix/var/nix/gcroots/skyflake";
        description = ''
          Directory which is mounted on all nodes, is linked from
          /nix/var/nix/gcroots/, and contains links to all currently
          required microvms.
        '';
      };

      customizationModule = mkOption {
        type = types.path;
        default = ../default-customization.nix;
        description = ''
          NixOS module to add when extending a guest NixOS configuration
          with MicroVM settings.
        '';
      };
    };

    gc = {
      cron = mkOption {
        type = types.str;
        default = "@hourly";
        description = lib.mdDoc ''
          See `cron` in https://developer.hashicorp.com/nomad/docs/job-specification/periodic#periodic-parameters
        '';
      };
    };

    microvmUid = mkOption {
      type = types.int;
      default = 999;
      description = ''
        A fixed UID for MicroVM files makes sense for the whole cluster.
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
          Enable debug output. Do not use in production!
        '';
    };
  };
}