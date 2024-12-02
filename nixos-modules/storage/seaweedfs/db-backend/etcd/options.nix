{
  lib,
  config,
  options,
  ...
}:
{
  options.skyflake.storage.seaweedfs.filer.db.etcd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use to enable Kubernetes etcd database as a backend for seaweedfs.
      '';
    };
    trustedCaFile = lib.mkOption {
      description = "Certificate authority file to use for clients";
      default = null;
      type = lib.types.nullOr lib.types.path;
    };
    certFile = lib.mkOption {
      description = "Cert file to use for clients";
      default = null;
      type = lib.types.nullOr lib.types.path;
    };
    keyFile = lib.mkOption {
      description = "Key file to use for clients";
      default = null;
      type = lib.types.nullOr lib.types.path;
    };
    peerCertFile = lib.mkOption {
      description = "Cert file to use for peer to peer communication";
      default = config.skyflake.storage.seaweedfs.filer.db.etcd.certFile;
      defaultText = lib.literalExpression "config.${options.skyflake.storage.seaweedfs.filer.db.etcd.certFile}";
      type = lib.types.nullOr lib.types.path;
    };
    peerKeyFile = lib.mkOption {
      description = "Key file to use for peer to peer communication";
      default = config.skyflake.storage.seaweedfs.filer.db.etcd.keyFile;
      defaultText = lib.literalExpression "config.${options.skyflake.storage.seaweedfs.filer.db.etcd.keyFile}";
      type = lib.types.nullOr lib.types.path;
    };
    peerTrustedCaFile = lib.mkOption {
      description = "Certificate authority file to use for peer to peer communication";
      default = config.skyflake.storage.seaweedfs.filer.db.etcd.trustedCaFile;
      defaultText = lib.literalExpression "config.${options.skyflake.storage.seaweedfs.filer.db.etcd.trustedCaFile}";
      type = lib.types.nullOr lib.types.path;
    };
  };
}
