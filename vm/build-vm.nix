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
          microvm.nixosModules.microvm
          {
            microvm = {
              # Overrride with custom-built squashfs
              bootDisk = bootDisk;
              # Prepend (override) regInfo with our custom-built
              kernelParams = pkgs.lib.mkBefore [ "regInfo=${bootDisk.regInfo}" ];
            };
            system.build.skyflake-deployment = {
              inherit pkgs system datacenters user repo flakeRef vmName;
            };
          }
          # From the host's skyflake.deploy.customizationModule
          @customizationModule@
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
