{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  lockInterceptorSrc = builtins.fetchGit {
    url = "https://github.com/izvyk/lock-monitor.git";
    rev = "99623650eaae4e6f9b49834f62cff00d76c159de";
  };
in
{

  # imports = [
  # ];

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;
  services.gnome.sushi.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
  # services.gnome.gnome-keyring.enable = lib.mkDefault false;

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
        "${lockInterceptorSrc}/lock-monitor.nix"
      ];

      services.lock-monitor =
        let
          caffeineStateFile = "/tmp/.caffeine-was-enabled-${username}";
        in
        {
          enable = true;

          lockScript = ''
            # ${pkgs.playerctl}/bin/playerctl pause

            # Save the caffeine state
            ${pkgs.coreutils}/bin/rm -f "${caffeineStateFile}"

            if [ "$(${pkgs.dconf}/bin/dconf read /org/gnome/shell/extensions/caffeine/cli-toggle)" = "true" ]; then
              ${pkgs.coreutils}/bin/touch "${caffeineStateFile}"
            fi
            ${pkgs.dconf}/bin/dconf write /org/gnome/shell/extensions/caffeine/cli-toggle false

            # Reset keyboard layout
            ${pkgs.glib}/bin/gdbus call --session --dest org.gnome.Shell \
                                        --object-path /dev/galets/gkr \
                                        --method dev.galets.gkr.reset
          '';

          unlockScript = ''
            # ${pkgs.playerctl}/bin/playerctl play

            ${pkgs.dconf}/bin/dconf write /org/gnome/shell/extensions/caffeine/cli-toggle true

            # Restore the caffeine state
            if [ -f "${caffeineStateFile}" ]; then
              ${pkgs.dconf}/bin/dconf write /org/gnome/shell/extensions/caffeine/cli-toggle true
              ${pkgs.coreutils}/bin/rm -f "${caffeineStateFile}"
            fi
          '';
        };

      # Explicit dconf entries - GNOME Wayland reads these
      dconf.settings = {
        "org/gnome/desktop/input-sources" = {
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
          font-name = "Roboto Condensed 13";
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
          cycle-windows = [ "<Control>grave" ];
          cycle-windows-backward = [ "<Shift><Control>grave" ];
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
          screensaver = [ "F23" ];
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/"
          ];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>Return";
          command = "footclient";
          name = "Terminal";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          binding = "Launch5";
          command = "/home/${username}/.local/bin/volume-down";
          name = "Volume down F14";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
          binding = "Launch6";
          command = "/home/${username}/.local/bin/volume-up";
          name = "Volume up F15";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
          binding = "Launch7";
          command = "/home/${username}/.local/bin/brightness-down";
          name = "Brightness down F16";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
          binding = "Launch8";
          command = "/home/${username}/.local/bin/brightness-up";
          name = "Brightness up F17";
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
          disable-extension-version-validation = true;
          disable-user-extensions = false;
          enabled-extensions = [
            "caffeine@patapon.info"
            # "clipboard-indicator@tudmotu.com"
            "disconnect-wifi@kgshank.net"
            "do-not-disturb-while-screen-sharing-or-recording@marcinjahn.com"
            "gsconnect@andyholmes.github.io"
            "middleclickclose@paolo.tranquilli.gmail.com"
            "panel-corners@aunetx"
            "just-perfection-desktop@just-perfection"
            # "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
            "color-picker@tuberry"
            "pip-on-top@rafostar.github.com"
            # "gocr@leonid.nasedkin"
            "shotzy@SamkitJain660.github.io"
            # "copyous@boerdereinar.dev"
            "vicinae@dagimg-dot"
            "keyboard-reset@galets"
            "touchpad-gesture-customization@coooolapps.com"
            "rounded-window-corners@fxgn"
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
        "org/gnome/settings-daemon/plugins/power".power-button-action = "nothing";

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
        gnomeExtensions.shotzy
        gnomeExtensions.copyous
        gnomeExtensions.panel-corners
        gnomeExtensions.just-perfection
        gnomeExtensions.middle-click-to-close-in-overview
        # gnomeExtensions.simple-break-reminder
        gnomeExtensions.vicinae
        gnomeExtensions.keyboard-reset
        gnomeExtensions.touchpad-gesture-customization
        gnomeExtensions.rounded-window-corners-reborn

        nautilus
        file-roller # Adds extraction support back to Nautilus
        gnome-calculator
        gnome-calendar
      ];
    };
}
