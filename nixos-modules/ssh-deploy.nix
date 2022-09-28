{ microvm, nixpkgs }:

{ config, lib, pkgs, ... }:

let
  deployCommand = with pkgs; writeScript "skyflake-ssh-deploy" ''
    #! ${runtimeShell} -e

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

    PATH=${lib.makeBinPath ([
      git nix
      config.services.nomad.package
    ])}:$PATH

    REF="\$1"
    REV="\$3"

    if [[ "\$REF" =~ ^refs/heads/([\\-_a-zA-Z0-9]+)$ ]]; then
      NAME="\''${BASH_REMATCH[1]}"
    else
      echo "Invalid ref \$REF"
      exit 1
    fi

    FLAKETMP=\$(mktemp --tmpdir -d deploy-flake-\$NAME-XXXX)
    git archive \$REV | tar xp -C "\$FLAKETMP"
    FLAKE=\$(nix store add-path "\$FLAKETMP" -n "$REPO")
    rm -r "\$FLAKETMP"

    echo "Skyflake condenses $REPO#\$NAME"
    cd ${../vm}
    nix build -f build-vm.nix \
      -o "$SYSTEMS/\$NAME" \
      --arg nixpkgsRef "\"${nixpkgs}\"" \
      --arg system "\"${pkgs.system}\"" \
      --arg datacenters '${lib.generators.toPretty {} cfg.datacenters}' \
      --arg user "\"\$USER\"" \
      --arg repo "\"$REPO\"" \
      --arg flakeRef "\"\$FLAKE\"" \
      --arg vmName "\"\$NAME\"" \
      --arg microvmFlake "\"${microvm}\""
    END_OF_HOOK
      chmod a+x hooks/update

      # Run git operation
      GIT_DIR=. git-receive-pack .

      cd $SYSTEMS
      echo "Skyflake is launching machines:" >&2
      for SYSTEM in $(ls -1) ; do
        echo $SYSTEM >&2
        nomad run -detach "$SYSTEM" >/dev/null
      done
      rm -r $SYSTEMS
      echo All done >&2
    else
      echo "Invalid SSH_ORIGINAL_COMMAND: $SSH_ORIGINAL_COMMAND" >&2
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

in {
  options.skyflake.deploy = with lib; {
    datacenters = mkOption {
      type = with types; listOf str;
      default = [ config.skyflake.nomad.datacenter ];
      description = ''
        List of datacenters to deploy to.
      '';
    };
  };

  config = {
    services.openssh.enable = true;

    users.users = builtins.mapAttrs (_: userConfig: {
      openssh.authorizedKeys.keys = map (sshKey:
        "${lib.concatStringsSep "," sshKeyOpts} ${sshKey}"
      ) userConfig.sshKeys;
    }) config.skyflake.users;
  };
}
