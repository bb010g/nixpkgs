{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    optionalString
    types
    ;

  dataDir = "/var/lib/squeezelite";
  cfg = config.services.squeezelite;
  bin = cfg.finalPackage + "/bin/${cfg.finalPackage.meta.mainProgram}";
in
{

  ###### interface

  options.services.squeezelite = {
    enable = mkEnableOption "the Squeezelite headless player for Lyrion Music Server";

    package = mkPackageOption pkgs "Squeezelite" { default = [ "squeezelite" ]; };

    finalPackage = mkPackageOption pkgs "configured Squeezelite" { default = null; } // {
      readOnly = true;
    };

    pulseAudio = mkEnableOption "PulseAudio backend";

    extraArguments = mkOption {
      default = "";
      type = types.str;
      description = ''
        Additional command line arguments to pass to Squeezelite.
      '';
    };
  };

  ###### implementation

  config = mkMerge [
    {
      services.squeezelite.finalPackage =
        if cfg.pulseAudio then
          cfg.package.override {
            audioBackend = "pulse";
            pulseSupport = null;
          }
        else
          cfg.package;
    }
    (mkIf cfg.enable {
      environment.systemPackages = [ cfg.finalPackage ];

      systemd.services.squeezelite = {
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "sound.target"
        ];
        description = "Squeezelite headless player for Lyrion Music Server";
        documentation = [ "man:squeezelite(5)" ];
        serviceConfig = {
          DynamicUser = true;
          ExecStart = "${bin} -N ${dataDir}/player-name ${cfg.extraArguments}";
          StateDirectory = builtins.baseNameOf dataDir;
          SupplementaryGroups = "audio";
        };
      };
    })
  ];
}
