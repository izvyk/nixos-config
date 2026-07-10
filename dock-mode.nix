{
  config,
  pkgs,
  lib,
  ...
}:

let
  targetUser = "izvyk";
  cameraUsbId = "1-4";
  audioPciId = "0000:03:00.6";
  authFile = "/sys/bus/usb/devices/${cameraUsbId}/authorized";

  reserveWrapper = pkgs.writeShellScriptBin "audio-reserve-wrapper" ''
    set -eu
    CARD_NUM=$(${pkgs.gawk}/bin/awk -F'[][]' '/LaptopAudio/ {print $1}' /proc/asound/cards | ${pkgs.coreutils}/bin/tr -d ' ')

    if [ -z "$CARD_NUM" ]; then
      ${pkgs.util-linux}/bin/logger -t dock-manager "could not resolve card number for ${audioPciId}"
      exit 1
    fi

    ${pkgs.util-linux}/bin/logger -t dock-manager "reserving Audio$CARD_NUM"
    exec ${pkgs.pipewire}/bin/pw-reserve -n "Audio$CARD_NUM" -r
  '';

  # Minimal, hardcoded, privileged-only writers - nothing else runs as root
  camWriteOff = pkgs.writeShellScriptBin "cam-write-off" ''
    ${pkgs.coreutils}/bin/echo 0 > ${authFile}
  '';

  camWriteOn = pkgs.writeShellScriptBin "cam-write-on" ''
    ${pkgs.coreutils}/bin/echo 1 > ${authFile}
  '';

  camOff = pkgs.writeShellScriptBin "cam-unauthorize" ''
    if [ -e ${authFile} ]; then
      /run/wrappers/bin/doas ${camWriteOff}/bin/cam-write-off \
        && ${pkgs.util-linux}/bin/logger -t dock-manager "camera unauthorized" \
        || ${pkgs.util-linux}/bin/logger -t dock-manager "camera unauthorize failed"
    fi
  '';

  camOn = pkgs.writeShellScriptBin "cam-authorize" ''
    if [ -e ${authFile} ]; then
      /run/wrappers/bin/doas ${camWriteOn}/bin/cam-write-on \
        && ${pkgs.util-linux}/bin/logger -t dock-manager "camera authorized" \
        || ${pkgs.util-linux}/bin/logger -t dock-manager "camera authorize failed"
    fi
  '';
in
{
  home-manager.users.${targetUser} = {
    imports = [
      /home/izvyk/Projects/dock-monitor/dock-monitor.nix
    ];

    services.dock-monitor = {
      enable = true;
      dockModeUnit = "dock-mode.service";
    };

    systemd.user.services.dock-mode = {
      Unit = {
        Description = "Dock mode: reserve laptop speakers&mic, unauthorize internal camera";
        # No After/BindsTo on graphical-session.target here -
        # this unit is purely reactive, started/stopped by dock-evaluate.
      };
      Service = {
        Type = "simple";
        ExecStartPre = "${camOff}/bin/cam-unauthorize";
        ExecStart = "${reserveWrapper}/bin/audio-reserve-wrapper";
        ExecStopPost = "${camOn}/bin/cam-authorize";
        Restart = "on-failure";
        RestartSec = "1";
      };
      # Deliberately no Install section - never auto-started at boot,
      # only ever via `systemctl --user start/stop dock-mode.service`.
    };
  };

  security.doas.extraRules = lib.mkAfter [
    {
      users = [ "${targetUser}" ];
      cmd = "${camWriteOff}/bin/cam-write-off";
      args = [ ];
      noPass = true;
    }
    {
      users = [ "${targetUser}" ];
      cmd = "${camWriteOn}/bin/cam-write-on";
      args = [ ];
      noPass = true;
    }
  ];

  # Stable device name
  services.udev.extraRules = ''
    SUBSYSTEM=="sound", KERNEL=="card*", KERNELS=="${audioPciId}", ATTR{id}="LaptopAudio"
  '';
}
