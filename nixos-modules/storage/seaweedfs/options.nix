{
  lib,
  ...
}:
{
  options.skyflake.storage.seaweedfs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        enable seaweedfs as the storage backend.
      '';
    };
    volumeStorage = {
      encrypt = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          enable encryption on volume store.
        '';
      };
      #datacenter = {
      #  type = lib.str;
      #  description = ''
      #    The datacenter location of the node.
      #  '';
      #};
      #rack = {
      #  type = lib.str;
      #  description = ''
      #    The rack location of the node.
      #  '';
      #};
    };
    s3 = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If you want to expose an S3 compatible bucket.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8333;
        description = ''
          The port the S3 API should listen to.
        '';
      };
    };
    mounts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mountSource = lib.mkOption {
              type = lib.types.str;
              default = null;
              example = "/filesystems/1a32bfd9-0cbc-430a-a28a-d9fd862e9ebc";
              description = ''
                Place where the filesystem is saved in seaweedfs.
              '';
            };
            replication = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.u8;
              default = null;
              description = ''
                Is the replication level for each file.
                It overwrites replication settings on both filer and master.
              '';
            };
            cacheCapacity = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 0;
              description = ''
                Means file chunk read cache capacity in MB with tiered cache(memory + disk),
                default 0 which means chunk cache for read is disabled.
              '';
            };
            chunkSizeLimit = lib.mkOption {
              type = lib.types.ints.positive;
              default = 2;
              description = ''
                Local write buffer size, also chunk large file, default 2 MB.
              '';
            };
          };
        }
      );
    };
    filer = {
      #TODO
      size = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30000;
        description = ''
          TODO
        '';
      };
      #TODO
      deviceClass = lib.mkOption {
        type = lib.types.str;
        default = "unset";
        example = ''
          `NVME` `SSD` `HDD`
        '';
        description = ''
          hard drive or solid state drive or any tag.
        '';
      };
    };
  };
}
