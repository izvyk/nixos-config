{
  config,
  pkgs,
  lib,
  ...
}:

let
  ddcciToggle = pkgs.writeShellApplication {
    name = "ddcciToggle";
    text = ''
      for conn in /sys/class/drm/card*-DP-*; do
        i2c=( "$conn"/i2c-* )
        [ -e "''${i2c[0]}" ] || continue

        i2c_path="''${i2c[0]}"
        [ -d "$i2c_path" ] || continue
        num=''${i2c_path##*-}
        echo "i2c_path is $i2c_path (num is $num)"

        i2c_dev="$num-0037"
        i2c_driver="/sys/bus/i2c/drivers/ddcci"

        ddcci_dev="ddcci$num"
        ddcci_driver="/sys/bus/ddcci/drivers/ddcci-backlight"

        if [ "$(cat "$conn/status")" = "connected" ]; then
          echo "state: connected"
          sleep 3

          if [ ! -e "$i2c_path/$i2c_dev" ]; then
            echo ddcci 0x37 > "$i2c_path/new_device" && echo "driver attached" || echo "error while attaching"
          else
            echo "driver already attached"
          fi


          if [ ! -e "$i2c_path/$i2c_dev" ]; then
            echo "$i2c_dev" > "$i2c_driver/bind" && echo "i2c driver bound" || echo "i2c driver binding failed"
          else
            echo "i2c driver already bound"
          fi

        else
          echo "state: disconnected"

          # 1. Unbind the virtual child backlight slider
          if [ -e "$ddcci_driver/$ddcci_dev" ]; then
            echo "$ddcci_dev" > "$ddcci_driver/unbind" && echo "removed /sys/class/backlight/$ddcci_dev" || echo "error while unbinding ddcci driver"
          else
            echo "already gone: /sys/class/backlight/$ddcci_dev"
          fi

          # 2. Unbind the parent I2C driver
          if [ -e "$i2c_driver/$i2c_dev" ]; then
            echo "$i2c_dev" > "$i2c_driver/unbind" && echo "i2c driver unbound" || echo "i2c driver unbinding failed"
          else
            echo "i2c driver already unbound"
          fi

          if [ -e "$i2c_path/$i2c_dev" ]; then
            echo 0x37 > "$i2c_path/delete_device" && echo "driver detached" || echo "error while detaching"
          else
            echo "driver already detached"
          fi
          echo "teardown complete for monitor on i2c-$num"
        fi
      done
    '';
  };
  mutterBacklightReload = pkgs.writers.writePython3Bin "mutter-backlight-reload" {
    libraries = [ pkgs.python3Packages.dbus-fast ];
  } (builtins.readFile ./mutter-backlight-reload.py);
in
{
  systemd.user.services.mutter-backlight-reload = {
    Unit.Description = "Force Mutter to re-detect backlight devices";
    Service = {
      Type = "oneshot";
      ExecStart = "${mutterBacklightReload}/bin/mutter-backlight-reload";
    };
  };

  boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
  boot.kernelModules = [
    "ddcci"
    "ddcci_backlight"
  ];

  systemd.services."ddcci-toggle" = {
    description = "Attach/detach ddcci backlight device on monitor hotplug";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe ddcciToggle;
    };
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ddcci-toggle.service"
  '';
  # ACTION=="change", SUBSYSTEM=="drm", KERNEL=="card1", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ddcci-toggle.service"
}
