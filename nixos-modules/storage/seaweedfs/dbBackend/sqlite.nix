{ pkgs, lib, config, ... }:

let
  seaweedFS-filer-file = pkgs.formats.toml ''
    [sqlite]
    # local on disk.
    enabled = false
    dbFile = "./filer.db"  # sqlite db file
  '';

in {
  config = lib.mkIf config.skyflake.storage.seaweedfs.filer.db.sqlite.enable {
    systemd.services.seaweedfs-filer = {
      description = "seaweedFS filer storage node";
      wantedBy = [ "multi-user.target" ];
      # after = [ "network-online.target" ] # TODO add firewall
        # ++ nixpgs.lib.optional config.networking.firewall.enable "firewall.service";
      # wants = [ "network-online.target" ]
        # ++ nixpgs.lib.optional config.networking.firewall.enable "firewall.service";

      #environment = {
      #};


      unitConfig = {
        Documentation = "https://github.com/seaweedfs/seaweedfs/wiki";
      };

      serviceConfig = {
        Type = "notify";
        Restart = "always";
        RestartSec = "30s";
        ExecStart = "${pkgs.seaweedfs}/bin/weed filer";
        User = "seaweedfs-filer";
        Group = "seaweedfs-filer";
        LimitNOFILE = 40000;
        WorkingDirectory = "/var/lib/seaweedfs-filer";
        SyslogIdentifier = "seaweedfs-filer";
      };
    };
    users.users.seaweedfs-filer = {
      isSystemUser = true;
      group = "seaweedfs-filer";
      description = "seaweedfs filer store user";
      home = config.systemd.services.seaweedfs-filer.WorkingDirectory;
    };
    users.groups.seaweedfs-filer = {};

    environment.etc = {
      "seaweedFS-filer" = {
        source = "${seaweedFS-filer-file}";
        target = "seaweedfs/filer.toml";
        mode = "0440";
      };
    };

    environment.systemPackages = [ pkgs.seaweedfs ];
  };
}