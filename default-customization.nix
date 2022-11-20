{ config, lib, ... }:

let
  generateMacAddress = s:
    let
      hash = builtins.hashString "sha256" s;
      c = off: builtins.substring off 2 hash;
    in
      "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";

  inherit (config.system.build.skyflake-deployment) user repo vmName;

in
{
  # custom options
  options.deployment = with lib; {
    vcpu = mkOption {
      type = types.int;
      default = 2;
    };
    mem = mkOption {
      type = types.int;
      default = 256;
    };
  };

  # some sensible defaults
  config.microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = config.deployment.vcpu;
    mem = config.deployment.mem;

    shares = [ {
      proto = "virtiofs";
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
    } ];
    volumes = [ {
      image = "/storage/glusterfs/persist/${user}/${repo}/${vmName}";
      mountPoint = "/";
      size = 8 * 1024;
    } ];
    writableStoreOverlay = "/nix/.rw-store";

    interfaces = [ {
      type = "tap";
      # Linux interface names cannot be longer than 15 bytes.
      # Note that this scheme can lead to clashes between
      # identical vmNames in separate user/repo.
      id = builtins.substring 0 15 "${user}-${vmName}";
      mac = generateMacAddress "${user}-${repo}-${vmName}";
    } ];
  };

  # Simply attach to main bridge
  config.skyflake.deploy.startTapScript = ''
    ip link set dev "$IFACE" master br0
  '';

  config.fileSystems."/".fsType = lib.mkForce "ext4";
}
