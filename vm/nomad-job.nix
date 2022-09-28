{ user
, repo
, vmName
, datacenters
, pkgs
, config
, runner
}:

let
  inherit (pkgs) lib;

  # stateDir = "/run/user/$UID/${user}/${repo}/${vmName}";
  stateDir = "$XDG_RUNTIME_DIR/microvms/${user}/${repo}/${vmName}";

  # TODO: attach to bridge?
  runTuntap = { id, ... }:
    pkgs.writeScript "tuntap-${vmName}-${id}" ''
      #!${pkgs.runtimeShell} -e
      if [ -d /sys/class/net/${id} ]; then
        ip tuntap del ${id} mode tap || true
      fi
      ip tuntap add ${id} mode tap user microvm
    '';
  # change working directory before starting virtiofsd
  runVirtiofsd = { tag, socket, source, ... }:
    pkgs.writeScript "virtiofsd-${vmName}-${tag}" ''
      #!${pkgs.runtimeShell} -e

      mkdir -p ${stateDir}
      cd ${stateDir}

      mkdir -p ${source}
      exec ${pkgs.virtiofsd}/bin/virtiofsd \
        --socket-path=${socket} \
        --socket-group=kvm \
        --shared-dir=${source} \
        --sandbox=none
    '';
  # change working directory before starting hypervisor,
  runMicrovm =
    pkgs.writeScript "hypervisor-${vmName}" ''
      #!${pkgs.runtimeShell} -e

      mkdir -p ${stateDir}
      cd ${stateDir}

      # start hypervisor
      exec ${runner}/bin/microvm-run
    '';
  stopMicrovm =
    pkgs.writeScript "hypervisor-${vmName}-stop" ''
      #!${pkgs.runtimeShell} -e

      mkdir -p ${stateDir}
      cd ${stateDir}

      # stop hypervisor on signal
      function handle_signal() {
        ${runner}/bin/microvm-shutdown
        exit
      }
      trap handle_signal TERM
      # wait
      while true; do
        sleep 86400 &
        # catch signals:
        wait
      done
    '';
in pkgs.writeText "${user}-${repo}-${vmName}.job" ''
  job "${user}-${repo}-${vmName}" {
    datacenters = [${lib.concatMapStringsSep ", " (datacenter:
      "\"${datacenter}\""
    ) datacenters}]
    type = "service"

    group "nixos-${config.system.nixos.label}" {
      count = 1
      restart {
        attempts = 1
        delay = "2s"
        mode = "delay"
        interval = "10s"
      }
      ${lib.concatMapStrings (interface@{ id, ... }: ''
        task "interface-${id}" {
          lifecycle {
            hook = "prestart"
          }
          driver = "raw_exec"
          user = "root"
          config {
            command = "${runTuntap interface}"
          }
        }
      '') config.microvm.interfaces}

      ${lib.concatMapStrings (share@{ tag, ... }: ''
        task "virtiofsd-${tag}" {
          lifecycle {
            hook = "prestart"
            sidecar = true
          }
          driver = "raw_exec"
          user = "root"
          config {
            command = "${runVirtiofsd share}"
          }
          kill_signal = "SIGCONT"
          kill_timeout = "15s"

          resources {
            memory = ${toString (config.microvm.vcpu * 32)}
            cpu = ${toString (config.microvm.vcpu * 10)}
          }
        }
      '') config.microvm.shares}

      task "hypervisor" {
        driver = "raw_exec"
        user = "microvm"
        config {
          command = "${runMicrovm}"
        }
        # don't get killed immediately but get shutdown by wait-shutdown
        kill_signal = "SIGCONT"
        kill_timeout = "15s"

        resources {
          memory = ${toString config.microvm.mem}
          cpu = ${toString (config.microvm.vcpu * 50)}
        }
        # TODO: cpu core constraint

      }

      task "wait-shutdown" {
        driver = "raw_exec"
        user = "microvm"
        config {
          command = "${stopMicrovm}"
        }
        kill_signal = "SIGTERM"
      }
    }
  }
''
