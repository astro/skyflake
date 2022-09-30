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
            ./nixos-modules/nodes.nix
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
          example2 = makeExampleSystem 2;
          example3 = makeExampleSystem 3;
        };

      apps.${system} =
        let
          makeExample = instance: {
            type = "app";
            program = "${self.nixosConfigurations."example${toString instance}".config.microvm.declaredRunner}/bin/microvm-run";
          };
        in {
          default = makeExample 1;
          example1 = makeExample 1;
          example2 = makeExample 2;
          example3 = makeExample 3;
        };
    };
}
