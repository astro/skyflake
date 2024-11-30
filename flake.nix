{
  description = "Hyperconverged Infratructure for NixOS";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    nomad-nixpkgs = {
      url = "github:NixOS/nixpkgs/1457235a9eee6e05916cd543d3143360e6fd1080"; # Last version of NixOS unstable that supports a foss version of nomad.
    };
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cache-cut = {
      url = "github:astro/nix-cache-cut";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nomad-nixpkgs, microvm, nix-cache-cut }:
    let
      system = "x86_64-linux";

      pkgs = nixpkgs.legacyPackages.${system};

    in {
      formatter.${system} = pkgs.alejandra;
      packages.${system} = import ./pkgs/doc.nix {
        inherit pkgs self;
      };

      nixosModules = {
        default = {
          imports = [
            {nixpkgs.overlays = [ (final: prev: { nomadPin = nomad-nixpkgs.legacyPackages.${prev.system}; }) ];}
            ./nixos-modules/storage/seaweedfs/options.nix
            ./nixos-modules/storage/seaweedfs/server.nix
            ./nixos-modules/storage/seaweedfs/dbBackend/etcd.nix
            ./nixos-modules/storage/ceph/server.nix
            ./nixos-modules/defaults.nix
            ./nixos-modules/nodes.nix
            ./nixos-modules/nomad.nix
            ./nixos-modules/users.nix
            ./nixos-modules/ssh-deployOptions.nix
            (import             
              ./nixos-modules/storage/seaweedfs/ssh-deploy.nix {
                inherit microvm nixpkgs; 
              }
            )
            (import
              ./nixos-modules/storage/ceph/ssh-deploy.nix {
                inherit microvm nixpkgs; 
              } 
            )
            {
              nixpkgs.overlays = [
                nix-cache-cut.overlays.default
              ];
            }
            ./nixos-modules/cache-cut.nix
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

          make-ceph = {
            type = "app";
            program = toString (pkgs.callPackage ./pkgs/make-ceph.nix {});
          };

        };
    };
}
