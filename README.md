# Skyflake: Hyperconverged Infrastructure for NixOS

- No Docker, no Kubernetes
- Hosts run NixOS, payloads are NixOS in [microvm.nix](https://github.com/astro/microvm.nix)
- Static hosts, dynamic virtual machines managed by Nomad
- Deploy machines by `git push` your Nix Flake

## Running the example cluster

- Have a bridge `virbr0`.
- Provide Internet access.
- Have 3x 4 GB RAM.
- Have 3x 20 GB disk.

- Put your SSH public key into `example-server.nix`
- Run MicroVMs in parallel:

  ```bash
  nix run .#example1
  nix run .#example2
  nix run .#example3
  ```
- Login and check for the IP address.
- Next, create your user flake:

  ```nix
  {
    outputs = { self, nixpkgs }: {
      nixosConfigurations =
        let
          mkHost = hostName:
            nixpkgs.lib.nixosSystem {
              modules = [ {
                system.stateVersion = "22.11";
                networking = { inherit hostName; };
                services.openssh = {
                  enable = true;
                  permitRootLogin = "yes";
                };
                users.users.root.password = "";
              } ];
              system = "x86_64-linux";
            };
        in {
          skytest1 = mkHost "skytest1";
          skytest2 = mkHost "skytest2";
          skytest3 = mkHost "skytest3";
          skytest4 = mkHost "skytest4";
        };
    };
  }
  ```
- Finally, deploy by pushing to a branch by hostname:

  ```shell
  git push test@10.23.23.43:example \
    HEAD:skytest1 HEAD:skytest2 \
    HEAD:skytest3 HEAD:skytest4
  ```

## How it works

The central component is a **nixosModule** that is configured for
servers to be part of a cluster.

Users have a flat hierarchy of flake repositories they can push
to. Their ssh interaction is forced into a custom script that lets
only `git push`, triggering a hook that does the following:

1. Builds the NixOS system
2. Copies the result into a cluster-shared binary cache
3. Runs the job on the cluster through Nomad

## Server configuration options

The nixosModule for the servers that make up the cluster provides the
following knobs:

*TODO*

## Deployment customization

Network setup, storage integration and more options of the MicroVMs
must be customized for the environment.

See `default-customization.nix`
