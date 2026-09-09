{
  pkgs,
  lib,
  username,
  inputs,
  ...
}:

let
  cameraUsbId = "1-4";
  audioPciId = "0000:03:00.6";
  authFile = "/sys/bus/usb/devices/${cameraUsbId}/authorized";

  dockLog = msg: ''${pkgs.util-linux}/bin/logger -t dock-mode "${msg}"'';

  reserveWrapper = pkgs.writeShellApplication {
    name = "audio-reserve-wrapper";
    text = ''
      CARD_NUM=$(${pkgs.gawk}/bin/awk -F'[][]' '/LaptopAudio/ {print $1}' /proc/asound/cards | ${pkgs.coreutils}/bin/tr -d ' ')

      if [ -z "$CARD_NUM" ]; then
        ${dockLog "could not resolve card number for ${audioPciId}"}
        exit 1
      fi

      ${dockLog "reserving Audio$CARD_NUM..."}
      exec ${pkgs.pipewire}/bin/pw-reserve -n "Audio$CARD_NUM" -r
    '';
  };

  # Builds a { writer, wrapper } pair for one camera-auth transition.
  # writer: minimal, hardcoded, root-only script (the only thing doas ever runs)
  # wrapper: unprivileged script - checks, elevates writer, logs as the real user
  mkCamAction =
    { value, verb }:
    let
      writer = pkgs.writeShellScriptBin "cam-write-${value}" ''
        ${pkgs.coreutils}/bin/echo ${value} > ${authFile}
      '';

      wrapper = pkgs.writeShellApplication {
        name = "cam-${verb}";
        text = ''
          if [ ! -e ${authFile} ]; then
            ${dockLog "camera under ${authFile} not found, skipping"}
            exit 0
          fi

          if /run/wrappers/bin/doas ${writer}/bin/cam-write-${value}; then
            ${dockLog "camera ${verb}d"}
          else
            ${dockLog "camera ${verb} failed"}
          fi
        '';
      };
    in
    {
      inherit writer wrapper;
    };

  camActions = {
    off = mkCamAction {
      value = "0";
      verb = "unauthorize";
    };
    on = mkCamAction {
      value = "1";
      verb = "authorize";
    };
  };

  # dockInterceptorSrc = builtins.fetchGit {
  #   url = "https://github.com/izvyk/dock-monitor.git";
  #   rev = "62e078a64909610d69abf7d321bb22744fdbefa3";
  # };
in
{
  home-manager.users.${username} = {
    imports = [
      "${inputs.godbus-monitor}/godbus-monitor.nix"
    ];

    services.godbus-monitor = {
      enable = true;
      triggers = [
        {
          name = "dock-lid-closed";
          bus = "system";
          sender = "org.freedesktop.login1";
          interface = "org.freedesktop.login1.Manager";
          property = "LidClosed";
          operator = "==";
          expected_value = "true";
          only_on_change = true;
          # debounce_ms = 3000;
          argv = [
            "sh"
            "-c"
            ''
              # Docked if GNOME is holding a blocking handle-lid-switch inhibitor
              # (that's exactly what dock-monitor's isDockedByInhibitor checked).
              # Small retry loop: the inhibitor can appear a beat after LidClosed flips.
              for i in 1 2 3 4 5; do
                if ${pkgs.systemd}/bin/busctl call org.freedesktop.login1 \
                     /org/freedesktop/login1 org.freedesktop.login1.Manager ListInhibitors \
                     2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '"handle-lid-switch[^"]*"[^]]*"block"'; then
                  ${pkgs.systemd}/bin/systemctl --user start dock-mode.service
                  exit 0
                fi
                ${pkgs.coreutils}/bin/sleep 0.2
              done
              # No inhibitor -> lid closed on battery, system is about to suspend. Leave as-is.
              exit 0
            ''
          ];
        }
        {
          name = "dock-lid-open";
          bus = "system";
          sender = "org.freedesktop.login1";
          interface = "org.freedesktop.login1.Manager";
          property = "LidClosed";
          operator = "==";
          expected_value = "false";
          only_on_change = true;
          # debounce_ms = 3000;
          argv = [
            "${pkgs.systemd}/bin/systemctl"
            "--user"
            "stop"
            "dock-mode.service"
          ];
        }
      ];
    };

    systemd.user.services.dock-mode = {
      Unit = {
        Description = "Dock mode: reserve laptop speakers&mic, unauthorize internal camera";
        # No After/BindsTo on graphical-session.target here -
        # this unit is purely reactive, started/stopped by dock-evaluate.
      };
      Service = {
        Type = "simple";
        ExecStartPre = "!${lib.getExe camActions.off.wrapper}";
        ExecStart = lib.getExe reserveWrapper;
        ExecStopPost = "!${lib.getExe camActions.on.wrapper}";
        Restart = "on-failure";
        RestartSec = "1";

        NoNewPrivileges = true;
      };
      # Deliberately no Install section - never auto-started at boot,
      # only ever via `systemctl --user start/stop dock-mode.service`.
    };
  };

  security.doas.extraRules = lib.mkAfter (
    map (action: {
      users = [ username ];
      cmd = lib.getExe action.writer;
      args = [ ];
      noPass = true;
    }) (lib.attrValues camActions)
  );

  # Stable device name
  services.udev.extraRules = ''
    SUBSYSTEM=="sound", KERNEL=="card*", KERNELS=="${audioPciId}", ATTR{id}="LaptopAudio"
  '';
}
