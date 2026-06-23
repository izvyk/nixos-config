{ config, pkgs, ... }:

let
  targetUser = "izvyk";

  cameraUsbId = "1-4";
  # activeAudioProfile = "HiFi (Mic1, Mic2, Speaker)";
  audioPciId = "0000:03:00.6";
  audioCardName = "alsa_card.pci-0000_03_00.6";

  dockScript = pkgs.writeShellScriptBin "toggle-dock-mode" ''
    # Find the user's UID for D-Bus connection (Script runs as root via ACPI/udev)
    USER_UID=$(id -u ${targetUser})
    export XDG_RUNTIME_DIR="/run/user/$USER_UID"

    LID_STATE=$(grep -iq "closed" /proc/acpi/button/lid/*/state && echo closed || echo open)
    EXT_MONITOR=$(grep -l "^connected$" /sys/class/drm/card*-*/status 2>/dev/null | grep -v eDP | wc -l)


    if [ "$LID_STATE" = "closed" ] && [ "$EXT_MONITOR" -gt 0 ]; then
      ${pkgs.util-linux}/bin/logger -t dock-manager "Evaluated state -> Lid: $LID_STATE | Ext Monitors: $EXT_MONITOR | Verdict: Docked"
      # ==========================================
      #               DOCKED MODE
      # ==========================================
      
      # 1. Banish Webcam (USB Authorized = 0)
      if [ -e /sys/bus/usb/devices/${cameraUsbId}/authorized ]; then
        echo 0 > /sys/bus/usb/devices/${cameraUsbId}/authorized && ${pkgs.util-linux}/bin/logger -t dock-manager "camera ${cameraUsbId} is successfully unauthorized" || ${pkgs.util-linux}/bin/logger -t dock-manager "failed to unauthorize camera ${cameraUsbId}"
      fi

      # 2. Banish Audio (Polite Unbind)
      # Step A: Tell WirePlumber to drop the file descriptors (without this the next command hangs)
      XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR ${pkgs.doas}/bin/doas -u ${targetUser} ${pkgs.pulseaudio}/bin/pactl set-card-profile ${audioCardName} off && ${pkgs.util-linux}/bin/logger -t dock-manager "audiocard ${audioCardName} profile is successfully set to off" || ${pkgs.util-linux}/bin/logger -t dock-manager "audiocard ${audioCardName} profile set failed: the card is probably already unbound"
      
      # Step B: Wait for WirePlumber to process the change
      sleep 0.5 

      # Step C: Yank the kernel driver safely
      if [ -d /sys/bus/pci/drivers/snd_hda_intel/${audioPciId} ]; then
        echo "${audioPciId}" > /sys/bus/pci/drivers/snd_hda_intel/unbind && ${pkgs.util-linux}/bin/logger -t dock-manager "audiocard ${audioCardName} is successfully unbound" || ${pkgs.util-linux}/bin/logger -t dock-manager "audiocard ${audioCardName} is already unbound"
      fi

    else
      ${pkgs.util-linux}/bin/logger -t dock-manager "Evaluated state -> Lid: $LID_STATE | Ext Monitors: $EXT_MONITOR | Verdict: Undocked"
      # ==========================================
      #             UNDOCKED MODE
      # ==========================================
      
      # 1. Restore Webcam (USB Authorized = 1)
      if [ -e /sys/bus/usb/devices/${cameraUsbId}/authorized ]; then
        echo 1 > /sys/bus/usb/devices/${cameraUsbId}/authorized && ${pkgs.util-linux}/bin/logger -t dock-manager "camera ${cameraUsbId} is successfully authorized" || ${pkgs.util-linux}/bin/logger -t dock-manager "failed to authorize camera ${cameraUsbId}"
      fi

      # 2. Restore Audio 
      # Step A: Rebind the kernel driver
      if [ ! -d /sys/bus/pci/drivers/snd_hda_intel/${audioPciId} ]; then
        echo "${audioPciId}" > /sys/bus/pci/drivers/snd_hda_intel/bind && ${pkgs.util-linux}/bin/logger -t dock-manager "audiocard ${audioCardName} is successfully bound" || ${pkgs.util-linux}/bin/logger -t dock-manager "audiocard ${audioCardName} is already bound"
      fi
    fi
  '';

  # This may be nice-to-have, but gnome actually switches the profile whenever the output is chosen in the menu. So restoring this is redundant and even unintuitive for the user
  # # Wait for the kernel and WirePlumber to discover the newly bound hardware
  # sleep 0.5
  # Step B: Reactivate the profile in WirePlumber
  # XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR ${pkgs.doas}/bin/doas -u ${targetUser} ${pkgs.pulseaudio}/bin/pactl set-card-profile ${audioCardName} "${activeAudioProfile}"
in
{
  # ACPI trigger for the physical lid switch
  services.acpid = {
    enable = true;
    handlers = {
      lid-dock = {
        event = "button/lid.*";
        action = "${dockScript}/bin/toggle-dock-mode";
      };
    };
  };

  # This is generally redundant but may be useful if the laptop is booted up with the lid closed so acpi won't trigger. TODO NEEDS TESTING
  # Udev trigger for display hotplugging via Direct Rendering Manager
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", RUN+="${dockScript}/bin/toggle-dock-mode"
  '';
}
