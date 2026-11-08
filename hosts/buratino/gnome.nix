{
  lib,
  pkgs,
  username,
  inputs,
  ...
}:

{

  # imports = [
  # ];

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # gnome-session 50 no longer runs gnome-keyring's autostart entries, and
  # nixpkgs builds gnome-keyring without its systemd units. So the first app
  # asking for secrets D-Bus-starts a second daemon, which re-initialises the
  # one PAM unlocked at login; that one then aborts (2 of 7 boots) and the
  # survivor asks for the password again. Run it as upstream intends: one
  # socket-activated daemon that PAM unlocks over its control socket.
  security.wrappers.gnome-keyring-daemon.source = lib.mkForce "${
    pkgs.gnome-keyring.overrideAttrs (old: {
      mesonFlags = lib.remove "-Dsystemd=disabled" old.mesonFlags;
      buildInputs = old.buildInputs ++ [ pkgs.systemd ];
    })
  }/bin/gnome-keyring-daemon";
  systemd.user.sockets.gnome-keyring-daemon = {
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "%t/keyring/control";
      DirectoryMode = "0700";
    };
  };
  systemd.user.services.gnome-keyring-daemon = {
    requires = [ "gnome-keyring-daemon.socket" ];
    serviceConfig = {
      # The wrapper adds cap_ipc_lock, so secrets stay out of swap.
      ExecStart = "/run/wrappers/bin/gnome-keyring-daemon --foreground --components=pkcs11,secrets --control-directory=%t/keyring";
      Restart = "on-failure";
    };
  };

  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;
  services.gnome.sushi.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
  # services.gnome.gnome-keyring.enable = lib.mkDefault false;
  # No SSH agent: it can't ask for a FIDO PIN in the terminal, so verify-required
  # keys fail through it. ssh reads the key files and prompts itself.
  services.gnome.gcr-ssh-agent.enable = false;

  programs.dconf.profiles.user.databases = [
    {
      lockAll = true; # prevents overriding
    }
  ];

  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  home-manager.users.${username} =
    { pkgs, ... }:
    {
      imports = [
        "${inputs.godbus-monitor}/godbus-monitor.nix"
      ];

      services.godbus-monitor =
        let
          caffeineStateFile = "/tmp/.caffeine-was-enabled-${username}";
          script = cmd: [
            "sh"
            "-c"
            cmd
          ];
        in
        {
          enable = true;

          triggers = [
            {
              name = "on-lock";
              bus = "system";
              sender = "org.freedesktop.login1";
              interface = "org.freedesktop.login1.Session";
              property = "LockedHint";
              operator = "==";
              expected_value = "true";
              only_on_change = true;
              # debounce_ms = 500;
              argv = script ''
                # Reset the keyboard layout as the shield starts falling
                ${pkgs.glib}/bin/gdbus call --session --dest org.gnome.Shell \
                                            --object-path /dev/galets/gkr \
                                            --method dev.galets.gkr.reset

                ${pkgs.playerctl}/bin/playerctl -a -i GSConnect pause

                # Save the caffeine state
                ${pkgs.coreutils}/bin/rm -f "${caffeineStateFile}"

                if [ "$(${pkgs.dconf}/bin/dconf read /org/gnome/shell/extensions/caffeine/cli-toggle)" = "true" ]; then
                  ${pkgs.coreutils}/bin/touch "${caffeineStateFile}"
                fi
                ${pkgs.dconf}/bin/dconf write /org/gnome/shell/extensions/caffeine/cli-toggle false
              '';
            }
            {
              name = "on-unlock";
              bus = "system";
              sender = "org.freedesktop.login1";
              interface = "org.freedesktop.login1.Session";
              property = "LockedHint";
              operator = "==";
              expected_value = "false";
              only_on_change = true;
              # debounce_ms = 500;
              argv = script ''
                # Restore the caffeine state
                if [ -f "${caffeineStateFile}" ]; then
                  ${pkgs.dconf}/bin/dconf write /org/gnome/shell/extensions/caffeine/cli-toggle true
                  ${pkgs.coreutils}/bin/rm -f "${caffeineStateFile}"
                fi
              '';
            }
            {
              name = "suspend-on-display-off";
              bus = "session";
              sender = "org.gnome.Mutter.DisplayConfig";
              interface = "org.gnome.Mutter.DisplayConfig";
              property = "PowerSaveMode";
              operator = ">";
              expected_value = "0";
              only_on_change = true;
              argv = script ''
                # Keep running while docked with the lid closed.
                ${pkgs.systemd}/bin/systemctl --user --quiet is-active dock-mode.service && exit 0

                ${pkgs.systemd}/bin/systemctl --no-block suspend-then-hibernate
              '';
            }
          ];
        };

      # Explicit dconf entries - GNOME Wayland reads these
      dconf.settings = {
        "org/gnome/desktop/input-sources" = {
          xkb-options = [ "fkeys:basic_13-24" ];
          sources = [
            (lib.gvariant.mkTuple [
              "xkb"
              "us+izvyk"
            ])
            (lib.gvariant.mkTuple [
              "xkb"
              "ru+izvyk"
            ])
          ];
        };

        "org/gnome/desktop/interface" = {
          clock-show-seconds = true;
          cursor-size = 24;
          cursor-theme = "Bibata-Modern-Classic";
          # enable-animations = true;
          accent-color = "teal";
          enable-hot-corners = false;
          show-battery-percentage = true;

          # Fonts
          font-name = "Iosevka Etoile Regular 13";
          document-font-name = "Literata 12";
          monospace-font-name = "Iosevka Curly 11";
        };
        "org/gnome/shell/app-switcher".current-workspace-only = true;
        "org/gnome/desktop/wm/preferences" = {
          # "button-layout".appmenu = [
          #   "minimize"
          #   "close"
          # ];
          focus-mode = "sloppy";
        };
        "org/gnome/desktop/wm/preferences/button-layout" = {
          appmenu = [
            "minimize"
            "close"
          ];
        };
        "org/gnome/desktop/screensaver".lock-delay = lib.gvariant.mkUint32 30;
        "system/locale".region = "de_DE.UTF-8";
        "org/gnome/desktop/privacy" = {
          remove-old-trash-files = true;
          remove-old-temp-files = true;
          recent-files-max-age = lib.gvariant.mkInt32 30;
        };
        "org/gnome/desktop/wm/keybindings" = {
          close = [ "<Super>q" ];
          cycle-windows = [ ];
          cycle-windows-backward = [ ];
          switch-windows = [ "<Control>Tab" ];
          switch-windows-backward = [ "<Shift><Control>Tab" ];
          # To avoid confusions when switching between iqunix keyboard and laptop keyboard
          unmaximize = [ "<Super>j" ];
          maximize = [ "<Super>k" ];
          minimize = [ "<Super>m" ];
        };
        "org/gnome/shell/keybindings" = {
          screenshot = [ "Print" ];
          show-screenshot-ui = [ "<Shift>Print" ];
          toggle-application-view = [ ];
        };

        "org/gnome/settings-daemon/plugins/media-keys" = {
          screensaver = [ "F21" ];
          help = [ ];
          home = [ "<Super>e" ];
          www = [ "<Super>w" ];
          # The wheel (F14/F15) uses the volume script below. Cleared because dconf
          # keeps a key once set, and these would fire as well.
          volume-down-precise = [ ];
          volume-up-precise = [ ];
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/"
          ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>Return";
          command = "footclient";
          name = "Terminal";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          binding = "F14";
          command = "/home/${username}/.local/bin/volume down";
          name = "Volume down";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
          binding = "F15";
          command = "/home/${username}/.local/bin/volume up";
          name = "Volume up";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
          binding = "F16";
          command = "/home/${username}/.local/bin/brightness down";
          name = "Brightness down";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
          binding = "F17";
          command = "/home/${username}/.local/bin/brightness up";
          name = "Brightness up";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
          binding = "<Super>v";
          command = "vicinae deeplink vicinae://launch/clipboard/history";
          name = "Vicinae clipboard manager";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6" = {
          binding = "<Super>d";
          command = "vicinae toggle";
          name = "Vicinae: toggle";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7" = {
          binding = "<Super>period";
          command = "vicinae deeplink vicinae://launch/core/search-emojis";
          name = "Vicinae emoji picker";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8" = {
          binding = "<Super>g";
          command = "/home/${username}/.local/bin/de-fix";
          name = "Correct German text in the clipboard";
        };

        "org/gnome/mutter" = {
          workspaces-only-on-primary = false;
          experimental-features = [
            "scale-monitor-framebuffer"
            "variable-refresh-rate"
            "xwayland-native-scaling"
          ];
        };

        "org/gnome/mutter/keybindings" = {
          toggle-tiled-left = [ "<Super>h" ];
          toggle-tiled-right = [ "<Super>l" ];
        };
        # "org/gnome/shell/extensions/clipboard-indicator".excluded-apps = [
        #   "org.keepassxc.KeePassXC"
        # ];
        "org/gnome/shell" = {
          always-show-log-out = true;
          disable-extension-version-validation = false;
          disable-user-extensions = false;
          enabled-extensions = [
            "caffeine@patapon.info"
            # "clipboard-indicator@tudmotu.com"
            "disconnect-wifi@kgshank.net"
            "do-not-disturb-while-screen-sharing-or-recording@marcinjahn.com"
            "gsconnect@andyholmes.github.io"
            "middleclickclose@paolo.tranquilli.gmail.com"
            # "panel-corners@aunetx"
            "just-perfection-desktop@just-perfection"
            # "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
            "color-picker@tuberry"
            "pip-on-top@rafostar.github.com"
            # "gocr@leonid.nasedkin"
            # "shotzy@SamkitJain660.github.io"
            # "copyous@boerdereinar.dev"
            "vicinae@dagimg-dot"
            "keyboard-reset@galets"
            "touchpad-gesture-customization@coooolapps.com"
            "rounded-window-corners@fxgn"
            # From chezmoi; tells the brightness scripts which monitor the pointer is on
            "pointer-monitor@phil"
          ];
        };
        "org/gnome/shell/extensions/just-perfection" = {
          activities-button = false;
          dash = false;
          top-panel-position = 1;
          window-demands-attention-focus = true;
          quick-settings-airplane-mode = false;
          search = false;
          window-preview-close-button = false;
          window-preview-caption = false;
          double-super-to-appgrid = false;
        };

        "org/gnome/shell/extensions/color-picker" = {
          enable-sound = false;
          enable-notify = true;
          enable-shortcut = true;
          color-picker-shortcut = [ "<Super>c" ];
          enable-systray = false;
          notify-style = 1;
        };

        "org/gnome/shell/extensions/vicinae" = {
          launcher-auto-close-focus-loss = true;
          show-status-indicator = false;
        };

        "org/gnome/settings-daemon/plugins/color" = {
          night-light-enabled = true;
          night-light-schedule-automatic = false;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          power-button-action = "nothing";
          sleep-inactive-ac-timeout = 315;
          sleep-inactive-battery-timeout = 315;
        };

        "org/gnome/desktop/session".idle-delay = 300;

        "org/gnome/shell/extensions/touchpad-gesture-customization" = {
          pinch-4-finger-gesture = "NONE";
          horizontal-swipe-3-fingers-gesture = "VOLUME_CONTROL";
          vertical-swipe-4-fingers-gesture = "OVERVIEW_NAVIGATION";
          pinch-3-finger-gesture = "NONE";
          volume-control-speed = 0.75;
        };

        "org/gnome/shell/extensions/rounded-window-corners-reborn" =
          let
            inherit (lib.gvariant)
              mkUint32
              mkTuple
              mkVariant
              mkArray
              mkDictionaryEntry
              ;
          in
          {
            global-rounded-corner-settings = mkArray [
              (mkDictionaryEntry "padding" (
                mkVariant (mkArray [
                  (mkDictionaryEntry "left" (mkVariant (mkUint32 0)))
                  (mkDictionaryEntry "right" (mkVariant (mkUint32 0)))
                  (mkDictionaryEntry "top" (mkVariant (mkUint32 0)))
                  (mkDictionaryEntry "bottom" (mkVariant (mkUint32 0)))
                ])
              ))
              (mkDictionaryEntry "keepRoundedCorners" (
                mkVariant (mkArray [
                  (mkDictionaryEntry "maximized" (mkVariant false))
                  (mkDictionaryEntry "fullscreen" (mkVariant false))
                ])
              ))
              (mkDictionaryEntry "borderRadius" (mkVariant (mkUint32 7)))
              (mkDictionaryEntry "smoothing" (mkVariant 0.0))
              (mkDictionaryEntry "borderColor" (
                mkVariant (mkTuple [
                  0.5
                  0.5
                  0.5
                  1.0
                ])
              ))
              (mkDictionaryEntry "enabled" (mkVariant true))
            ];
          };
      };

      # 1. Your user-specific packages go here!
      home.packages = with pkgs; [
        # gnomeExtensions.paperwm
        gnomeExtensions.caffeine
        gnomeExtensions.brightness-control-using-ddcutil
        # gnomeExtensions.clipboard-indicator
        gnomeExtensions.disconnect-wifi
        gnomeExtensions.do-not-disturb-while-screen-sharing-or-recording
        gnomeExtensions.gsconnect
        # gnomeExtensions.windownavigator
        gnomeExtensions.pip-on-top
        gnomeExtensions.color-picker
        # gnomeExtensions.gocr
        # gnomeExtensions.shotzy
        gnomeExtensions.copyous
        # gnomeExtensions.panel-corners
        gnomeExtensions.just-perfection
        gnomeExtensions.middle-click-to-close-in-overview
        # gnomeExtensions.simple-break-reminder
        gnomeExtensions.vicinae
        # From unstable: stable's version 9 doesn't declare support for Shell 50.
        # It only resets by itself on ActiveChanged, so on-lock also calls it.
        unstable.gnomeExtensions.keyboard-reset
        # gnomeExtensions.brightness-control-using-ddcutil
        gnomeExtensions.touchpad-gesture-customization
        gnomeExtensions.rounded-window-corners-reborn

        nautilus
        file-roller # Adds extraction support back to Nautilus
        gnome-calculator
        gnome-calendar
      ];
    };
}
