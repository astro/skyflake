{ config, pkgs, ... }:

let
  jobFile = pkgs.writeText "cache-gc.job" ''
    job "cache-gc" {
      type = "batch"
      datacenters = ["${config.skyflake.nomad.datacenter}"]
      periodic {
        cron = "${config.skyflake.gc.cron}"
        prohibit_overlap = true
      }
      task "nix-cache-cut" {
        driver = "raw_exec"
        config {
          command = "local/nix-cache-cut.sh"
        }
        template {
          destination = "local/nix-cache-cut.sh"
          perms = "755"
          data = <<EOD
    #! /run/current-system/sw/bin/bash -e

    PATH=/run/current-system/sw/bin
    exec nix-cache-cut ${config.skyflake.deploy.binaryCachePath} ${config.skyflake.deploy.sharedGcrootsPath}
    EOD
        }
        resources {
          memory = 64
          cpu = 500
        }
      }
    }
  '';

in
{
  environment.systemPackages = with pkgs; [
    nix-cache-cut
  ];

  systemd.services.skyflake-install-cache-gc = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "nomad.service" ];
    path = [ config.services.nomad.package ];
    script = ''
      nomad run -detach ${jobFile}
    '';
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 10;
      RemainAfterExit = true;
    };
  };
}
