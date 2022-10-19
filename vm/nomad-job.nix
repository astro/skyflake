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

  workDir = "/run/microvms/${user}/${repo}/${vmName}";

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
            command = "local/interface-${id}.sh"
          }
          template {
            destination = "local/interface-${id}.sh"
            perms = "755"
            data = <<EOD
${''
  #! /run/current-system/sw/bin/bash -e

  # TODO: attach to bridge?
  if [ -d /sys/class/net/${id} ]; then
    echo "WARNING: Removing stale tap interface ${id}" >&2
    ip tuntap del ${id} mode tap || true
  fi
  ip tuntap add ${id} mode tap user microvm
  ip link set ${id} up
''}EOD
          }
        }
        # TODO: interface remove poststop
      '') config.microvm.interfaces}

      ${lib.concatMapStrings (share@{ tag, source, socket, proto, ... }:
        lib.optionalString (proto == "virtiofs") ''
          task "virtiofsd-${tag}" {
            lifecycle {
              hook = "prestart"
              sidecar = true
            }
            driver = "raw_exec"
            user = "root"
            config {
              command = "local/virtiofsd-${tag}.sh"
            }
            template {
              destination = "local/virtiofsd-${tag}.sh"
              perms = "755"
              data = <<EOD
${''
  #! /run/current-system/sw/bin/bash -e

  mkdir -p ${workDir}
  chown microvm:kvm ${workDir}
  cd ${workDir}

  mkdir -p ${source}
  exec /run/current-system/sw/bin/virtiofsd \
    --socket-path=${socket} \
    --socket-group=kvm \
    --shared-dir=${source} \
    --sandbox=none
''}EOD
            }
            kill_signal = "SIGCONT"
            kill_timeout = "15s"

            resources {
              memory = ${toString (config.microvm.vcpu * 32)}
              cpu = ${toString (config.microvm.vcpu * 10)}
            }
          }
        '') config.microvm.shares}

      task "copy-system" {
        driver = "raw_exec"
        lifecycle {
          hook = "prestart"
        }
        config {
          command = "local/copy-system.sh"
        }
        template {
          destination = "local/copy-system.sh"
          perms = "755"
          data = <<EOD
${''
  #! /run/current-system/sw/bin/bash -e

  if ! [ -e ${runner} ] ; then
    /run/current-system/sw/bin/nix copy --from @sharedStorePath@ --no-check-sigs ${runner}
  fi
''}EOD
        }
      }

      task "volume-dirs" {
        driver = "raw_exec"
        lifecycle {
          hook = "prestart"
        }
        config {
          command = "local/make-dirs.sh"
        }
        template {
          destination = "local/make-dirs.sh"
          perms = "755"
          data = <<EOD
${''
  #! /run/current-system/sw/bin/bash -e

  ${lib.concatMapStrings ({ image, ... }: ''
    mkdir -p "${dirOf image}"
    chown microvm:kvm "${dirOf image}"
  '') config.microvm.volumes}
''}EOD
        }
      }

      task "hypervisor" {
        driver = "raw_exec"
        user = "microvm"
        config {
          command = "local/hypervisor.sh"
        }
        template {
          destination = "local/hypervisor.sh"
          perms = "755"
          data = <<EOD
${''
  #! /run/current-system/sw/bin/bash -e

  mkdir -p ${workDir}
  cd ${workDir}

  # start hypervisor
  exec ${runner}/bin/microvm-run
''}EOD
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
          command = "local/wait-shutdown.sh"
        }
        template {
          destination = "local/wait-shutdown.sh"
          perms = "755"
          data = <<EOD
${''
  #! /run/current-system/sw/bin/bash -e

  mkdir -p ${workDir}
  cd ${workDir}

  # stop hypervisor on signal
  function handle_signal() {
    echo "Received signal, shutting down" >&2
    ${runner}/bin/microvm-shutdown
    echo "Done" >&2
    exit
  }
  trap handle_signal TERM
  # wait
  while true; do
    sleep 86400 &
    # catch signals:
    wait
  done
''}EOD
        }

        kill_signal = "SIGTERM"
      }
    }
  }
''
