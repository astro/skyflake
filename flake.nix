{
  description = "Hyperconverged Infratructure for NixOS";

  inputs = {
    microvm.url = "github:astro/microvm.nix";
  };
  
  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";

    in {

      nixosModules = {
        default = {
          imports = [
            ./nixos-modules/defaults.nix
            ./nixos-modules/nomad.nix
            ./nixos-modules/users.nix
            (import ./nixos-modules/ssh-deploy.nix {
              inherit microvm nixpkgs;
            })
          ];
        };
      };

      nixosConfigurations =
        let
          makeExampleSystem = instance:
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                microvm.nixosModules.microvm
                self.nixosModules.default
                (import ./example-server.nix { inherit instance; })
              ];
            };

        in {
          example1 = makeExampleSystem 1;
        };

      apps.${system} = rec {
        default = example1;
        example1 = {
          type = "app";
          program = "${self.nixosConfigurations.example1.config.microvm.declaredRunner}/bin/microvm-run";
        };
      };
      
    };
}
