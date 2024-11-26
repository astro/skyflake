# NixOS in Flakes

## What is a Nix Flake?

Flakes mandate a top-level file `flake.nix` with a well-defined
interface to well-known Nix functionality, such as packages, overlays,
hydraJobs, **nixosConfigurations**, and more. Skyflake relies on Nix
Flakes for their well-defined exposure of multiple NixOS
configurations.

Flakes are versioned (git). All their external inputs are versioned
into a `flake.lock` file. No more fumbling with system generations
when everything is properly versioned in git.

## How do I define NixOS configurations in Flakes?

A sample `flake.nix`:

```nix
{
  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      my-microvm = nixpkgs.lib.nixosSystem {
        modules = [ {
          system.stateVersion = "24.11";
          networking.hostName = "my-microvm";
          services.openssh = {
            enable = true;
            permitRootLogin = "yes";
          };
          users.users.root = {
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 ..."
            ];
          };
        } ];
        system = "x86_64-linux";
      };
    };
  };
}
```

This file lives in a repository:

```bash
git init
git add flake.nix
```

While the `nixpkgs` input is implicit, it must still be pinned:

```bash
nix flake lock
git add flake.lock
git commit -m Hello\ World
```
