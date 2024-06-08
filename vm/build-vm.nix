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
  microvm = builtins.getFlake microvmFlake;
  flake = builtins.getFlake flakeRef;

  # The imported NixOS system
  original = flake.nixosConfigurations.${vmName};

  extended =
    # Safety checks
    if original.config ? microvm
    then throw ''
      VM config must not already contain microvm configuration! Use options from the customizationModule instead.

      Value: ${pkgs.lib.generators.toPretty {} original.config.microvm}
    ''
    else if original.config ? skyflake
    then throw ''
      VM config must not already contain skyflake configuration! Use options from the customizationModule instead.

      Value: ${pkgs.lib.generators.toPretty {} original.config.skyflake}
    ''
    else
      # Customizations to the imported NixOS system
      original.extendModules {
        modules = [
          microvm.nixosModules.microvm
          ./customization-options.nix
          {
            config = {
              system.build.skyflake-deployment = {
                inherit pkgs system datacenters user repo flakeRef vmName;
              };
            };
          }
          # From the host's skyflake.deploy.customizationModule
        ];
      };

  runner = microvm.lib.buildRunner {
    inherit pkgs;
    microvmConfig = {
      hostName = vmName;
      inherit (extended.config.boot.kernelPackages) kernel;
    } // extended.config.microvm;
    inherit (extended.config.system.build) toplevel;
  };
in
import ./nomad-job.nix {
  inherit user repo vmName datacenters;

  inherit pkgs runner;
  inherit (extended) config;
}