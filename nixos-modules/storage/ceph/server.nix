{ config, lib, pkgs, ... }:
let
  inherit (config.networking) hostName;

  cfg = config.skyflake.storage.ceph;

  isMon = builtins.elem hostName cfg.mons;
  isMgr = builtins.elem hostName cfg.mgrs;
  isMds = builtins.elem hostName cfg.mdss;

  mdssPerServer = builtins.ceil (
    2.0
    * (builtins.length (builtins.attrNames cfg.cephfs))
    / (builtins.length cfg.mdss)
  );

  localMdss = lib.optionals isMds (
    builtins.genList (i:
      "${hostName}-${toString i}"
    ) mdssPerServer
  );

  isIPv6 = addr: builtins.match ".*:.*:.*" addr != null;
  escapeIPv6 = addr:
    if isIPv6 addr
    then "[${addr}]"
    else addr;

  poolParamsOpts = {
    size = lib.mkOption {
      type = with lib.types; nullOr int;
      default = null;
      description = "Replication target size";
      example = 2;
    };
    class = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = "Preferred device class";
      example = "ssd";
    };
  };

  setPoolParams = name: params:
    lib.optionalString (params.size != null) ''
      ceph osd pool set ${lib.escapeShellArg name} size ${toString params.size}
    '' +
    lib.optionalString (params.class != null) ''
      ceph osd pool set ${lib.escapeShellArg name} crush_rule "replicated_${params.class}"
    '';

in {
  options.skyflake.storage.ceph = {
    fsid = lib.mkOption {
      type = lib.types.str;
      example = "ed97c230-9613-4eef-8763-c6b0c6e3d8b8";
    };
    initialMonIp = lib.mkOption {
      type = lib.types.str;
      default = builtins.head cfg.mons;
    };
    mons = lib.mkOption {
      type = with lib.types; listOf str;
      default = lib.take 3 (builtins.attrNames config.skyflake.nodes);
    };
    mgrs = lib.mkOption {
      type = with lib.types; listOf str;
      default = lib.take 3 (builtins.attrNames config.skyflake.nodes);
    };
    mdss = lib.mkOption {
      type = with lib.types; listOf str;
      default = lib.take 3 (builtins.attrNames config.skyflake.nodes);
    };
    osds = lib.mkOption {
      default = [];
      type = with lib.types; listOf (submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.int;
            example = 0;
            description = "Ends up in `osd.0`";
          };
          fsid = lib.mkOption {
            type = lib.types.str;
            example = "ed97c230-9613-4eef-8763-c6b0c6e3d8b8";
          };
          path = lib.mkOption {
            type = str;
          };
          # TODO: walPath, dbPath
          deviceClass = lib.mkOption {
            type = str;
            example = "ssd";
          };
          keyfile = lib.mkOption {
            type = str;
            description = ''
              Just the base64-encoded key. Generate one with `ceph-authtool -g -C /dev/stdout`
            '';
          };
        };
      });
    };
    rbdPools = lib.mkOption {
      default = {};
      type = with lib.types; attrsOf (submodule ({ name, ... }: {
        options = {
          params = poolParamsOpts;
        };
      }));
    };
    monKeyring = lib.mkOption {
      type = lib.types.path;
    };
    adminKeyring = lib.mkOption {
      type = lib.types.path;
    };
    cephfs = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({
        options = {
          mountPoint = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
          };
          metaParams = poolParamsOpts;
          dataParams = poolParamsOpts;
        };
      }));
    };
  };

  config = {
    boot.kernelModules = [ "ceph" ];

    environment.systemPackages = [ pkgs.ceph ];
    environment.etc = {
      "ceph/ceph.mon.keyring".source = cfg.monKeyring;
      "ceph/ceph.client.admin.keyring".source = cfg.adminKeyring;
    };

    systemd.tmpfiles.rules = [
      "d /var/log/ceph 750 ceph ceph - -"
    ];

    services.ceph = rec {
      enable = true;
      global = rec {
        inherit (cfg) fsid;
        publicNetwork = clusterNetwork; #"0.0.0.0/0, ::/0";
        clusterNetwork = lib.concatStringsSep ", " (
          lib.concatMap ({ addresses ? [], ... }:
            lib.concatMap ({ addressConfig ? {}, ... }:
              if addressConfig ? Address
              then [ addressConfig.Address ]
              else []
            ) addresses
          ) (builtins.attrValues config.systemd.network.networks)
        );

        monHost = cfg.initialMonIp;
        monInitialMembers = builtins.concatStringsSep "," cfg.mons;
      };
      mon = rec {
        enable = isMon;
        daemons = lib.optional enable hostName;
      };
      mgr = rec {
        enable = isMgr;
        daemons = lib.optional enable hostName;
      };
      mds = rec {
        enable = isMds;
        daemons = localMdss;
        extraConfig = {
          # "Whichever one has not currently assigned a rank will be the standby replay follower of the other:"
          mds_standby_replay = "true";
          mds_standby_for_rank = "0";
        };
      };
      osd = {
        enable = cfg.osds != [];
        daemons = map ({ id, ... }: toString id) cfg.osds;
      };

      extraConfig = lib.optionalAttrs (isIPv6 config.skyflake.nodes.${hostName}.address) {
        "ms bind ipv4" = "false";
        "ms bind ipv6" = "true";
      };
    };

    systemd.services = lib.mkMerge ([ {
      bootstrap-ceph-mon = lib.mkIf isMon {
        description = "Ceph MON bootstap";
        after = [ "network.target" ];
        before = [ "ceph-mon-${hostName}.service" ];
        requiredBy = [ "ceph-mon-${hostName}.service" ];

        # TODO: more fine-grained than a `done` file?
        unitConfig.ConditionPathExists = "!/var/lib/ceph/mon/ceph-${hostName}/done";

        path = [ pkgs.ceph ];
        script = ''
          cp --no-preserve=mode ${cfg.monKeyring} /tmp/ceph.mon.keyring
          ceph-authtool /tmp/ceph.mon.keyring --import-keyring ${cfg.adminKeyring}
          #monmaptool --create --add ${hostName} v2:${cfg.initialMonIp}:3300/0 --fsid ${cfg.fsid} /tmp/monmap
          #monmaptool --create --add ${hostName} ${cfg.initialMonIp} --fsid ${cfg.fsid} /tmp/monmap
          monmaptool --create \
            ${lib.concatMapStringsSep " " (monHost:
              "--add ${monHost} ${escapeIPv6 config.skyflake.nodes.${monHost}.address}"
            ) cfg.mons} \
            --fsid ${cfg.fsid} \
            --clobber \
            /tmp/monmap
          ceph-mon --mkfs -i ${hostName} --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring

          rm -f /tmp/monmap /tmp/ceph.mon.keyring
          touch /var/lib/ceph/mon/ceph-${hostName}/done
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          User = "ceph";
          Group = "ceph";
        };
      };
      setup-ceph-mon = lib.mkIf isMon {
        description = "Ceph MON setup";
        after = [ "ceph-mon-${hostName}.service" ];
        wantedBy = [ "ceph-mon-${hostName}.service" ];

        path = [ pkgs.ceph ];
        script = ''
          ceph mon enable-msgr2
          ceph config set mon auth_allow_insecure_global_id_reclaim false
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "ceph";
          Group = "ceph";
        };
      };

      bootstrap-ceph-mgr = lib.mkIf isMgr {
        description = "Ceph MGR bootstap";
        before = [ "ceph-mgr-${hostName}.service" ];
        requiredBy = [ "ceph-mgr-${hostName}.service" ];

        unitConfig.ConditionPathExists = "!/var/lib/ceph/mgr/ceph-${hostName}/done";

        path = [ pkgs.ceph ];
        script = ''
          mkdir -p /var/lib/ceph/mgr/ceph-${hostName}
          ceph auth get-or-create mgr.${hostName} mon 'allow profile mgr' osd 'allow *' mds 'allow *' > /var/lib/ceph/mgr/ceph-${hostName}/keyring
          # TODO: ceph mgr module enable dashboard
          touch /var/lib/ceph/mon/ceph-${hostName}/done
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "ceph";
          Group = "ceph";
        };
      };
    } ]
    ++
    map (mds: {
      "bootstrap-ceph-mds-${mds}" = {
        description = "Ceph MDS bootstap";
        before = [ "ceph-mds-${mds}.service" ];
        wantedBy = [ "ceph-mds-${mds}.service" ];

        unitConfig.ConditionPathExists = "!/var/lib/ceph/mds/ceph-${mds}/keyring";

        path = [ pkgs.ceph ];
        script = ''
          mkdir -p /var/lib/ceph/mds/ceph-${mds}
          ceph auth get-or-create mds.${mds} mon 'profile mds' mgr 'profile mds' osd 'allow *' > /var/lib/ceph/mds/ceph-${mds}/keyring
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "ceph";
          Group = "ceph";
        };
      };
    }) localMdss
    ++
    map ({ id, fsid, path, keyfile, deviceClass, ... }: {
      "bootstrap-ceph-osd-${toString id}" = {
        description = "Ceph OSD.${toString id} bootstap";
        after = [
          "ceph-mon-${hostName}.service"
          "ceph-mgr-${hostName}.service"
        ];
        before = [ "ceph-osd-${toString id}.service" ];
        wantedBy = [ "ceph-osd-${toString id}.service" ];
        unitConfig.ConditionPathExists = "!/var/lib/ceph/osd/ceph-${toString id}";

        path = with pkgs; [ ceph ];
        script = ''
          # TODO: --block.db BLOCK_DB --block.wal BLOCK_WAL

          mkdir -p /var/lib/ceph/osd/ceph-${toString id}
          echo bluestore > /var/lib/ceph/osd/ceph-${toString id}/type
          ln -sf ${path} /var/lib/ceph/osd/ceph-${toString id}/block
          ceph-authtool --create-keyring /var/lib/ceph/osd/ceph-${toString id}/keyring \
            --name osd.${toString id} \
            --add-key "$(cat ${keyfile})"
          chown -R ceph:ceph /var/lib/ceph/osd/ceph-${toString id}

          echo "{\"cephx_secret\": \"$(cat ${keyfile})\"}" | ceph osd new ${fsid} ${toString id} -i -
          ceph-osd -i ${toString id} --mkfs --osd-uuid ${fsid}

          ceph osd crush rm-device-class osd.${toString id}
          ceph osd crush set-device-class ${lib.escapeShellArg deviceClass} osd.${toString id}
          ceph osd crush rule create-replicated "replicated_${deviceClass}" default host ${lib.escapeShellArg deviceClass}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    }) cfg.osds
    ++
    lib.optionals isMon (
      map (fsName: {
        "bootstrap-cephfs-${fsName}" = {
          description = "Create CephFS ${fsName}";
          requires = [ "ceph-mgr-${hostName}.service" ];
          path = with pkgs; [ ceph ];
          # successful even on existing cephfs
          script = ''
            ceph fs volume create ${lib.escapeShellArg fsName}
            ${setPoolParams "cephfs.${fsName}.meta" cfg.cephfs.${fsName}.metaParams}
            ${setPoolParams "cephfs.${fsName}.data" cfg.cephfs.${fsName}.dataParams}
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "3s";
          };
        };
      }) (builtins.attrNames cfg.cephfs))
    ++
    lib.optionals isMon (
      map (name: {
        "bootstrap-rbd-pool-${name}" = {
          description = "Create Ceph RBD pool ${name}";
          wantedBy = [ "multi-user.target" ];
          requires = [ "ceph-mgr-${hostName}.service" ];
          path = with pkgs; [ ceph ];
          # successful even on existing pool
          script = ''
            ceph osd pool create ${lib.escapeShellArg name} replicated
            ${setPoolParams name cfg.rbdPools.${name}.params}
            rbd pool init ${lib.escapeShellArg name}
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "3s";
          };
        };
      }) (builtins.attrNames cfg.rbdPools))
    );

    systemd.mounts = map (fsName:
      let
        inherit (cfg.cephfs.${fsName}) mountPoint;
      in {
        requires = lib.optionals isMon [
          "bootstrap-cephfs-${fsName}.service"
          "ceph-mgr-${hostName}.service"
        ];
        requiredBy = [ "nomad.service" ];
        type = "ceph";
        what = "${lib.concatMapStringsSep "," (mon: escapeIPv6 config.skyflake.nodes.${mon}.address) cfg.mons}:/";
        where = mountPoint;
        options = lib.concatStringsSep "," [
          "fs=${fsName}"
          # use ceph.client.admin.keyring
          "name=admin"
        ];
      }
    ) (builtins.attrNames (
      lib.filterAttrs (_: { mountPoint, ... }:
        mountPoint != null
      ) cfg.cephfs
    ));
  };
}
