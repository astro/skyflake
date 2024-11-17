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
      image = config.skyflake.deploy.ceph.rbds.root.path;
      mountPoint = "/";
      # don't let microvm.nix create an image file
      autoCreate = false;
      size = 0;
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

  config.skyflake.deploy.ceph.rbds.root = {
    pool = "microvms";
    namespace = user;
    name = "${repo}-${vmName}-root";
    size = 512;
  };

  # Simply attach to main bridge
  config.skyflake.deploy.startTapScript = ''
    ip link set dev "$IFACE" master br0
  '';

  # Constraint example
  config.skyflake.nomadJob.constraints = [ {
    attribute = "\${meta.example-deployment}";
    operator = "=";
    value = "yes";
  } ];
  config.skyflake.nomadJob.affinities = [ {
    attribute = "\${meta.example-deployment}";
    value = "yes";
  } ];

  config.fileSystems."/".fsType = lib.mkForce "ext4";
}
