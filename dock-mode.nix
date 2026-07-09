{ config, pkgs, ... }:

let
  targetUser = "izvyk";
  cameraUsbId = "1-4";
  audioPciId = "0000:03:00.6";

  uid = toString config.users.users.${targetUser}.uid;

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

  camOff = pkgs.writeShellScriptBin "cam-unauthorize" ''
    if [ -e /sys/bus/usb/devices/${cameraUsbId}/authorized ]; then
      ${pkgs.coreutils}/bin/echo 0 > /sys/bus/usb/devices/${cameraUsbId}/authorized \
        && ${pkgs.util-linux}/bin/logger -t dock-manager "camera unauthorized" \
        || ${pkgs.util-linux}/bin/logger -t dock-manager "camera unauthorize failed"
    fi
  '';

  camOn = pkgs.writeShellScriptBin "cam-authorize" ''
    if [ -e /sys/bus/usb/devices/${cameraUsbId}/authorized ]; then
      ${pkgs.coreutils}/bin/echo 1 > /sys/bus/usb/devices/${cameraUsbId}/authorized \
        && ${pkgs.util-linux}/bin/logger -t dock-manager "camera authorized" \
        || ${pkgs.util-linux}/bin/logger -t dock-manager "camera authorize failed"
    fi
  '';

  evalScript = pkgs.writeShellScriptBin "dock-evaluate" ''
    set -eu
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.systemd
	pkgs.util-linux
      ]
    }:$PATH"

    if [ ! -S "/run/user/${uid}/bus" ]; then
      logger -t dock-manager "session bus not ready, skipping evaluation"
      exit 0
    fi

    LID_STATE=$(grep -iq "closed" /proc/acpi/button/lid/*/state && echo closed || echo open)
    EXT_MONITOR=$(grep -l "^connected$" /sys/class/drm/card*-*/status 2>/dev/null | grep -v eDP | wc -l)

    if [ "$LID_STATE" = "closed" ] && [ "$EXT_MONITOR" -gt 0 ]; then
      systemctl start dock-mode.service
    else
      systemctl stop dock-mode.service
    fi
  '';
in
{
  systemd.services."dock-mode" = {
    description = "Dock mode: disable internal camera/speakers when docked with lid closed";
    after = [ "graphical.target" ];
    unitConfig = {
      ConditionPathExists = "/run/user/${uid}/bus";
      StartLimitIntervalSec = "30";
      StartLimitBurst = "5";
    };
    serviceConfig = {
      Type = "simple";
      User = targetUser;
      Environment = "XDG_RUNTIME_DIR=/run/user/${uid}";
      ExecStartPre = "!${camOff}/bin/cam-unauthorize";
      ExecStart = "${reserveWrapper}/bin/audio-reserve-wrapper";
      ExecStopPost = "!${camOn}/bin/cam-authorize";
      Restart = "on-failure";
      RestartSec = "1";
    };
  };

  systemd.services."dock-evaluate" = {
    description = "Re-evaluate dock state on lid/DRM change";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${evalScript}/bin/dock-evaluate";
    };
  };

  # ACPI trigger for the physical lid switch
  services.acpid = {
    enable = true;
    handlers = {
      lid-change = {
        event = "button/lid.*";
        action = "${evalScript}/bin/dock-evaluate";
      };
    };
  };

  # Stable device name
  services.udev.extraRules = ''
    SUBSYSTEM=="sound", KERNEL=="card*", KERNELS=="${audioPciId}", ATTR{id}="LaptopAudio"
  '';
}
