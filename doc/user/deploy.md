# Deploying

For deployment, you don't need to install some untrusted vendor's
toolchain. Instead, Skyflake leverages the standard method for
transferring your flake repository: **git push**

You can have multiple deployment flakes that they push to via SSH.

To select which `nixosConfigurations` of a flake shall be built and
deployed on a `git push` we use git branches.

Assuming that you have a Skyflake account `alice` on Skyflake host
deploy.example.net, push the current git commit (`HEAD`) to remote
flake `my-infra` to (re-)deploy hosts `www`, `ftp`, and `bittorrent`:

```bash
git push alice@deploy.example.net:my-infra \
    HEAD:www HEAD:ftp HEAD:bittorrent
```

The remote machine will now receive your git data, build the
`nixosConfigurations` by specified revision. You are not disconnected
from SSH yet; you'll get the build output feedback, able to interrupt
before it finishes. Once the builds have finished successfully, the
machines are scheduled for reboot.

Your local git state should now include the updated remote branches.
