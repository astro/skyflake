{ nixpkgsRef ? "github:nixos/nixpkgs/nixpkgs-unstable"
, system
, datacenters
, microvmFlake ? "github:astro/microvm.nix"
, user
, repo
, flakeRef
, vmName
}:

let
  nixpkgs = builtins.getFlake nixpkgsRef;
  pkgs = nixpkgs.legacyPackages.${system};
  inherit (pkgs) lib;
  microvm = builtins.getFlake microvmFlake;
  flake = builtins.getFlake flakeRef;

  generateMacAddress = s:
    let
      hash = builtins.hashString "sha256" s;
      c = off: builtins.substring off 2 hash;
    in
      "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";

  # The imported NixOS system
  original = flake.nixosConfigurations.${vmName};

  extended =
    # Safety check
    if original.config ? microvm
    then throw "VM config must not already contain microvm configuration! Use skyflake.vm instead."
    else
      # Customizations to the imported NixOS system
      original.extendModules {
        modules = [
          {
            # Overrride with custom-built squashfs
            microvm.bootDisk = bootDisk;
            # Prepend (override) regInfo with our custom-built
            microvm.kernelParams = pkgs.lib.mkBefore [ "regInfo=${bootDisk.regInfo}" ];
            # Override other microvm.nix defaults
            microvm.hypervisor = "cloud-hypervisor";
            # TODO: make configurable
            microvm.vcpu = 1;
            microvm.mem = 256;
            microvm.shares = [ {
              proto = "virtiofs";
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
            } ];
            # microvm.volumes = [ {
            #   image = "/storage/${vmName}";
            #   mountPoint = config.microvm.writableStoreOverlay;
            #   size = 8 * 1024;
            # } ];
            # microvm.writableStoreOverlay = "/nix/.rw-store";
            microvm.interfaces = [ {
              type = "tap";
              id =
                let
                  u = if builtins.stringLength user > 4
                      then builtins.substring 0 4 (
                        builtins.hashString "sha256" user
                      ) else user;
                  r = if builtins.stringLength repo > 4
                      then builtins.substring 0 4 (
                        builtins.hashString "sha256" repo
                      ) else repo;
                  n = builtins.hashString "sha256" vmName;
                in
                  builtins.substring 0 15 "${u}-${r}-${n}";
              mac = generateMacAddress "${user}-${repo}-${vmName}";
            } ];
          }

          microvm.nixosModules.microvm
        ];
      };

  inherit (extended.config.boot.kernelPackages) kernel;

  # Build the squashfs ourselves
  bootDisk = microvm.lib.buildErofs {
    inherit pkgs;
    inherit (extended) config;
  };

  runner = microvm.lib.buildRunner {
    inherit pkgs kernel bootDisk;
    microvmConfig = {
      hostName = vmName;
    } // extended.config.microvm;
    inherit (extended.config.system.build) toplevel;
  };
in
import ./nomad-job.nix {
  inherit user repo vmName datacenters;

  inherit pkgs runner;
  inherit (extended) config;
}
