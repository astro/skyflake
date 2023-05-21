# Setting up Skyflake users

Skyflake builds a multi-tenant cluster. For each tenant, a NixOS user
will be created. These users do not get shell access via SSH but are
forced to run the special deployment handler.

```nix
skyflake.users.test = {
  uid = 1000;
  sshKeys = [
    # ...
  ];
};
```

For stability, you must specify a static UID.

You can instruct your tenants to use only one build host for SSH
deployment. If more than server is used, share the user's home between
the machines by putting it on CephFS.
