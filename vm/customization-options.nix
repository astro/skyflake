{ lib, ... }:
{
  options.skyflake = with lib; {
    deploy.startTapScript = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Commands to run for a TAP interface of MicroVM to be started.

        Part of the nomad job. Do not rely on store paths here.
      '';
    };
    deploy.stopTapScript = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Commands to run for a TAP interface after a MicroVM is shut down.

        Part of the nomad job. Do not rely on store paths here.
      '';
    };

    # TODO: rename it to something that allows more than ceph.
    deploy.rbds = mkOption {
      default = {};
      description = ''
        Ceph RBDs used by this MicroVM
      '';
      type = with types; attrsOf (submodule ({ name, ... }: {
        options = {
          pool = mkOption {
            type = str;
          };
          namespace = mkOption {
            type = str;
          };
          name = mkOption {
            type = str;
          };
          size = mkOption {
            type = nullOr int;
            default = null;
          };
          autoCreate = mkOption {
            type = bool;
            default = true;
          };
          fsType = mkOption {
            type = str;
            default = "ext4";
            description = ''
              Which mkfs to use when `autoCreate = true`
            '';
          };
          path = mkOption {
            type = str;
            default = "rbd/${name}";
            description = "Automatic. Don't change";
          };
        };
      }));
    };

    nomadJob.affinities = mkOption {
      default = [];
      type = with types; listOf (submodule ({
        options = {
          attribute = mkOption {
            type = str;
          };
          operator = mkOption {
            type = enum [
              "=" "!=" ">" ">=" "<" "<="
              "regexp" "version"
              "set_contains_all" "set_contains_any"
            ];
            default = "=";
          };
          value = mkOption {
            type = str;
          };
          weight = mkOption {
            type = ints.between (-100) 100;
            default = 50;
          };
        };
      }));
    };
    nomadJob.constraints = mkOption {
      default = [];
      type = with types; listOf (submodule ({
        options = {
          attribute = mkOption {
            type = str;
          };
          operator = mkOption {
            type = enum [
              "=" "!=" ">" ">=" "<" "<="
              "distinct_hosts" "distinct_property"
              "regexp"
              "set_contains" "set_contains_any"
              "version" "semver"
              "is_set" "is_not_set"
            ];
            default = "=";
          };
          value = mkOption {
            type = str;
          };
        };
      }));
    };
  };
}
