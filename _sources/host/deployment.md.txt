# Customizing deployment

Users shall be able to start MicroVMs based on NixOS
configurations. Depending on your and your tenant's intentions, and on
your network setup, you must customize the deployment.

Skyflake lets the host set a `customizationModule` that will be
forcibly imported into every NixOS deployment. Tweak your tenant's
NixOS configuration towards your infrastructure here.

```nix
skyflake.deploy.customizationModule = ./my-customization;
```

While the `customizationModule` can point to a single `.nix` file,
refering to a whole subdirectory lets you include other files along a
`default.nix` file.

## Dealing with NixOS options

In the `customizationModule` you are expected to define NixOS options
that model what resources are available to tenants. Once they set
those in their nixosConfigurations, they won't be able to build them
anymore because the options are only declared in your
`customizationModule`, available only on deploy through SSH.

As a stopgap solution, we propose defining all your deployment
options, *and really just the options,* in a separate flake that can
be used by you and your tenants.
