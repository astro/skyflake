{ microvm, nixpkgs }:

{ config, lib, pkgs, ... }:

let
  inherit (config.skyflake.storage.ceph) cephfs;

  debugShell = lib.optionalString config.skyflake.debug ''
    set -x
  '';

  deployCommand = with pkgs; writeScript "skyflake-ssh-deploy" ''
    #! ${runtimeShell} -e
    ${debugShell}

    PATH=${lib.makeBinPath ([
      git
    ])}:$PATH

    if [[ "$SSH_ORIGINAL_COMMAND" =~ ^git-receive-pack\ \'([\\-_a-zA-Z0-9]+)\'$ ]]; then
      REPO="''${BASH_REMATCH[1]}"
      if ! [ -e $REPO ]; then
        echo "Creating $REPO anew..." >&2
        mkdir $REPO
        cd $REPO
        ${git}/bin/git init --bare -b main >/dev/null
      else
        echo "Updating existing $REPO" >&2
        cd $REPO
      fi

      SYSTEMS=$(mktemp --tmpdir -d deploy-systems-XXXXXXXX)

      cat > hooks/update <<END_OF_HOOK
    #! ${runtimeShell} -e
    ${debugShell}

    PATH=${lib.makeBinPath ([
      git nix
      config.services.nomad.package
    ])}:\$PATH

    REF="\$1"
    REV="\$3"

    if [[ "\$REF" =~ ^refs/heads/([\\-_a-zA-Z0-9]+)$ ]]; then
      NAME="\''${BASH_REMATCH[1]}"
    else
      echo "Invalid ref \$REF"
      exit 1
    fi

    if [[ "\$REV" =~ ^0+\$ ]]; then
      # Deleting branch, stop microvm
      nomad job stop -namespace "$USER-$REPO" "\$NAME" || true
      exit 0
    fi

    # the branch doesn't exist yet but is required by a git+file:///
    # flakeref. instead, we're archiving into a blank directory and add that
    # to the /nix/store so it can be used as a flakeref.
    FLAKETMP=\$(mktemp --tmpdir -d deploy-flake-\$NAME-XXXX)
    git archive \$REV | tar xp -C "\$FLAKETMP"
    FLAKE=\$(nix store add-path "\$FLAKETMP" -n "$REPO")
    rm -r "\$FLAKETMP"

    echo "Skyflake is cooking $REPO#\$NAME"
    nix build -f /etc/skyflake/vm/build-vm.nix \
      -o "$SYSTEMS/\$NAME" \
      --extra-substituters file://${cfg.binaryCachePath}/?trusted=1 \
      --arg nixpkgsRef "\"${nixpkgs}\"" \
      --arg system "\"${pkgs.system}\"" \
      --arg datacenters '${lib.generators.toPretty {} cfg.datacenters}' \
      --arg user "\"\$USER\"" \
      --arg repo "\"$REPO\"" \
      --arg flakeRef "\"\$FLAKE\"" \
      --arg vmName "\"\$NAME\"" \
      --arg microvmFlake "\"${microvm}\""

    SYSTEM=\$(readlink "$SYSTEMS/\$NAME")
    # Copy to shared store
    sudo nix copy --to file://${cfg.binaryCachePath} --no-check-sigs "\$SYSTEM"
    # Register gcroot
    mkdir -p "${cfg.sharedGcrootsPath}/$USER/$REPO"
    rm -f "${cfg.sharedGcrootsPath}/$USER/$REPO/\$NAME"
    rm -f "${cfg.sharedGcrootsPath}/$USER/$REPO/\$NAME"
    ln -s "\$SYSTEM" "${cfg.sharedGcrootsPath}/$USER/$REPO/\$NAME"

    END_OF_HOOK
      chmod a+x hooks/update

      # Run git operation
      GIT_DIR=. git-receive-pack .

      cd $SYSTEMS
      if [ -z "$(ls -1A)" ]; then
        echo "No systems were built."
        exit 0
      fi

      echo "Skyflake is launching machines:" >&2
      nomad namespace apply "$USER-$REPO" >/dev/null

      for NAME in * ; do
        SYSTEM=$(readlink $NAME)
        echo $SYSTEM >&2
        nomad run -detach "$SYSTEM" >&2

        # Register gcroot
        mkdir -p "${cfg.sharedGcrootsPath}/$USER/$REPO"
        rm -f "${cfg.sharedGcrootsPath}/$USER/$REPO/$NAME"
        ln -s "$SYSTEM" "${cfg.sharedGcrootsPath}/$USER/$REPO/$NAME"
      done
      cd -
      rm -r $SYSTEMS
      echo All done >&2

    elif [[ "$SSH_ORIGINAL_COMMAND" =~ ^git-upload-pack\ \'([\\-_a-zA-Z0-9]+)\'$ ]]; then
      REPO="''${BASH_REMATCH[1]}"
      exec git-upload-pack "$REPO"

    elif [[ "$SSH_ORIGINAL_COMMAND" = status ]]; then
      NAMESPACES=$(nomad namespace list -t "{{ range . }}{{ .Name }}
    {{ end }}"|grep -e "^$USER-")
      for NAMESPACE in $NAMESPACES ; do
        nomad job status -namespace "$NAMESPACE"
      done

    else
      echo "Invalid SSH command: $SSH_ORIGINAL_COMMAND" >&2
      exit 1
    fi
  '';

  sshKeyOpts = [
    "command=\"${deployCommand}\""
    "no-port-forwarding"
    "no-X11-forwarding"
    "no-agent-forwarding"
    "no-pty"
    "no-user-rc"
    "restrict"
  ];

  cfg = config.skyflake.deploy;
  gcCfg = config.skyflake.gc;

in {
  options.skyflake = with lib; {
    deploy = {
      datacenters = mkOption {
        type = with types; listOf str;
        default = [ config.skyflake.nomad.datacenter ];
        description = ''
          List of datacenters to deploy to.
        '';
      };

      binaryCachePath = mkOption {
        type = types.str;
        default = cephfs.skyflake-binary-cache.mountPoint;
        description = ''
          Directory which is mounted on all nodes that will be used to
          share the /nix/store with MicroVMs.
        '';
      };

      sharedGcrootsPath = mkOption {
        type = types.str;
        default = cephfs.skyflake-gcroots.mountPoint;
        description = ''
          Directory which is mounted on all nodes, is linked from
          /nix/var/nix/gcroots/, and contains links to all currently
          required microvms.
        '';
      };

      customizationModule = mkOption {
        type = types.path;
        default = ../default-customization.nix;
        description = ''
          NixOS module to add when extending a guest NixOS configuration
          with MicroVM settings.
        '';
      };
    };

    gc = {
      cron = mkOption {
        type = types.str;
        default = "@hourly";
        description = lib.mdDoc ''
          See `cron` in https://developer.hashicorp.com/nomad/docs/job-specification/periodic#periodic-parameters
        '';
      };
    };

    microvmUid = mkOption {
      type = types.int;
      default = 999;
      description = ''
        A fixed UID for MicroVM files makes sense for the whole cluster.
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
          Enable debug output. Do not use in production!
        '';
    };
  };

  config = {
    skyflake.storage.ceph.cephfs = {
      skyflake-binary-cache.mountPoint = "/var/lib/skyflake/binary-cache";
      skyflake-gcroots.mountPoint = "/nix/var/nix/gcroots/skyflake";
    };

    services.openssh.enable = true;

    users.users = builtins.mapAttrs (_: userConfig: {
      openssh.authorizedKeys.keys = map (sshKey:
        "${lib.concatStringsSep "," sshKeyOpts} ${sshKey}"
      ) userConfig.sshKeys;
    }) config.skyflake.users // {
      # stable uid is useful across network filesystems
      microvm.uid = config.skyflake.microvmUid;
    };

    environment.etc."skyflake/vm".source = pkgs.substituteAllFiles {
      src = ../vm;
      files = [ "." ];
      inherit (config.skyflake.deploy) binaryCachePath customizationModule;
    };

    # lets the hook use $binaryCachePath
    nix.settings.trusted-users = builtins.attrNames config.skyflake.users;

    # allowing commands to copy to/from shared store
    security.sudo = {
      enable = true;
      extraRules = [ {
        groups = [ "users" ];
        commands = [ {
          command = ''/run/current-system/sw/bin/nix copy --to file\://${cfg.binaryCachePath} *'';
          options = [ "NOPASSWD" ];
        } ];
      } ];
    };

    systemd.tmpfiles.rules =
      [
        # workDir for nomad jobs
        "d /run/microvms 0700 microvm kvm - -"
        "d ${cfg.binaryCachePath} 0777 root root - -"
      ]
      ++
      map (userName:
        "d ${config.skyflake.deploy.sharedGcrootsPath}/${userName} 0750 ${userName} root - -"
      ) (builtins.attrNames config.skyflake.users);

    systemd.services.skyflake-permissions = {
      wantedBy = [ "multi-user.target" ];
      after = [ "remote-fs.target" ];
      script = ''
        mkdir -p ${cfg.binaryCachePath}
        chmod 0777 ${cfg.binaryCachePath}

        ${lib.concatMapStrings (userName: ''
          D="${config.skyflake.deploy.sharedGcrootsPath}/${userName}"
          mkdir -p "$D"
          chown "${userName}" "$D"
        '') (builtins.attrNames config.skyflake.users)}
      '';
    };
  };
}
