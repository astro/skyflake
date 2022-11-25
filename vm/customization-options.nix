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
          };
          value = mkOption {
            type = str;
          };
        };
      }));
    };
  };
}
