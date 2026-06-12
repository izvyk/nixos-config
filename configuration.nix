# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  ...
}:

let
  # 1. Fetch the unstable tarball and assign its path to a variable
  unstable-src = fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  home-manager = fetchTarball "https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz";
  agenix-src = fetchTarball "https://github.com/ryantm/agenix/archive/main.tar.gz";

  # 1. We create a custom Tesseract instance with exactly the languages you need.
  # This avoids global bloat and ensures the data is present for this script.
  tesseract-ocr = pkgs.tesseract.override {
    enableLanguages = [
      "rus"
      "eng"
      "deu"
    ];
  };

  # 2. We define the script as a package.
  # "writeShellApplication" is superior to "writeShellScriptBin" because
  # it runs ShellCheck on build and handles PATH automatically.
  ocr-script = pkgs.writeShellApplication {
    name = "ocr-selection";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.imagemagick
      pkgs.wl-clipboard
      tesseract-ocr
    ];
    text = ''
      # The pipeline: Select -> Process -> OCR -> Clipboard
      grim -g "$(slurp)" - | \
        magick - -auto-level -normalize -enhance -sharpen 0x1 -resize 200% - | \
        tesseract - - -l rus+eng+deu quiet | \
        wl-copy
    '';
  };
  sharedMain = {
    # capslock = "escape";
    capslock = "overload(control, escape)";

    leftcontrol = "layer(alt)";
    leftalt = "layer(control)";

    rightalt = "overload(altgr, macro(leftmeta+space))";

    insert = "timeout(macro2(-1, 0, insert), 250ms, macro2(-1, 0, S-insert))";

    space = "overloadt(space_layer, space, 250)";
  };
  sharedSpaceLayer = {
    # Developer Additions: Vim navigation
    h = "left";
    j = "down";
    k = "up";
    l = "right";

    # Developer Additions: Quality of life
    n = "backspace";
    m = "delete";
  };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # <home-manager/nixos>
    (import "${home-manager}/nixos")

    # 2. Import the DMS module directly from the downloaded tarball path
    # "${unstable-src}/nixos/modules/programs/wayland/dms-shell.nix"
    "${unstable-src}/nixos/modules/programs/wayland/niri.nix"
    # "${unstable-src}/nixos/modules/programs/wayland/mangowc.nix"
    # "${unstable-src}/nixos/modules/services/system/nohang.nix"
    # "${unstable-src}/nixos/modules/services/hardware/logiops.nix"
    # "${unstable-src}/nixos/modules/services/hardware/keyd.nix"

    # Age module from agenix-src
    "${agenix-src}/modules/age.nix"
  ];

  # This tells NixOS to skip loading its default versions of these modules
  disabledModules = [
    "programs/wayland/niri.nix"
    # "programs/wayland/mangowc.nix"
    # "services/hardware/logiops.nix"
    # "services/hardware/keyd.nix"
  ];

  networking.hostName = "NixPC";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;
    wifi.backend = "iwd";
    plugins = with pkgs; [
      networkmanager-openvpn
    ];
  };
  systemd.services.NetworkManager-wait-online.enable = false;
  services.avahi.enable = false;
  systemd.services.ModemManager.enable = false;
  systemd.services.tailscaled.serviceConfig.Type = lib.mkForce "simple";
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ]; # no autostart but keep socket activation

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";
  time.timeZone = "Europe/Berlin";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";

    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "de_DE.UTF-8/UTF-8"
      "ru_RU.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_CTYPE = "en_US.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
      LC_COLLATE = "en_US.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_MESSAGES = "en_US.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_ADDRESS = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
    };
  };
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  ### services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  ### services.xserver.displayManager.gdm.enable = true;
  ### services.xserver.desktopManager.gnome.enable = true;

  # nixpkgs = {
  #   overlays = [
  #     (final: prev: {
  #       gnome = prev.gnome.overrideScope (
  #         gfinal: gprev: {
  #           gvfs = gprev.gvfs.override {
  #             googleSupport = true;
  #             gnomeSupport = true;
  #           };
  #         }
  #       );
  #     })
  #   ];
  #
  #   config = {
  #     permittedInsecurePackages = [
  #       "libsoup-2.74.3"
  #     ];
  #   };
  # };

  users.groups.battery = { };
  users.groups.power_profile = { };

  users.users.izvyk = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "video"
      "input"
      "networkmanager"
      "battery"
      "power_profile"
      "i2c"
      "libvirtd"
      "kvm"
      "adbusers"
    ];

  };

  # 2. Tell Home Manager to use the global system packages
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.izvyk =
    { pkgs, ... }:
    {
      # home.stateVersion = "25.11";

      home.pointerCursor = {
        name = "Bibata-Modern-Classic";
        package = pkgs.bibata-cursors;
        size = 24;
        gtk.enable = true;
        x11.enable = true; # Keep this true even on Wayland; many XWayland apps (like Electron) need it
      };

      # 1. Your user-specific packages go here!
      home.packages = with pkgs; [
        # firefox
        # foot # enabled as a service
        # unstable.ghostty
        # unstable.warp-terminal
        # unstable.nushell
        # yandex-music
        kdePackages.filelight
        # materialgram
        # telegram-desktop
        keepassxc
        # gparted
        mpv
        vscode
        qpwgraph
        cameractrls-gtk4
        eza
        # fusuma
        wl-clipboard
        # go
        playerctl
        udiskie
        # quickshell
        # yandex-music
        unstable.zed-editor
        unstable.opencode
        unstable.pi-coding-agent
        unstable.gemini-cli-bin
        unstable.antigravity
        lazygit
        unstable.yazi
        # gnumake
        # gcc
        # glibc.static
        chromium
        libreoffice
        # zoom-us

        # waybar
        # kdePackages.kdeconnect-kde
        awww
        killall
        # cliphist
        wl-gammarelay-rs
        # rofi
        # python3Minimal
        # jq
        # pulseaudio
        # swayimg
        unstable.libheif
        parallel
        unstable.imagemagickBig
        # unzip
        libnotify
        # grim
        # unstable.flameshot
        dotool
        ocr-script

        # unstable.noctalia-shell
        # unstable.quickshell # The underlying framework Noctalia runs on
        # unstable.brightnessctl
        # unstable.cliphist
        # unstable.wlsunset
        qt6.qtwayland
        kdePackages.qttools
        fd

        # unstable.vicinae
        # unstable.contour
        chezmoi
        # alacritty
        delta
        tmux

        unstable.devenv
        gocryptfs
        vaults
        obsidian
        unstable.tuxguitar
      ];

      # 2. Your foot config from earlier
      programs.foot = {
        enable = true;
        # server.enable = true;
      };
      # Declaratively enable the upstream socket by mimicking 'systemctl enable'
      xdg.configFile."systemd/user/sockets.target.wants/foot-server.socket".source =
        "${pkgs.foot}/share/systemd/user/foot-server.socket";

      # programs.dms-shell = {
      #   enable = true;
      #
      #   # Notice we use `pkgs.unstable` here because of your packageOverrides
      #   package = pkgs.unstable.dms;
      #   quickshell.package = pkgs.unstable.quickshell;
      # };

      # This value determines the Home Manager release that your configuration is
      # compatible with. This helps avoid breakage when a new Home Manager release
      # introduces backwards incompatible changes.
      #
      # You should not change this value, even if you update Home Manager. If you do
      # want to update the value, then make sure to first check the Home Manager
      # release notes.
      home.stateVersion = "25.11"; # Please read the comment before changing.
    };
  programs.niri = {
    enable = true;
    package = pkgs.unstable.niri;
  };

  age.secrets."btrbk-ssh-key" = {
    file = ./secrets/btrbk-ssh-key.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.btrbk = {
    instances.home = {
      onCalendar = "hourly";
      settings = {
        snapshot_preserve_min = "3d";
        snapshot_preserve = "2w 2M";

        stream_compress = "lz4";
        ssh_identity = config.age.secrets."btrbk-ssh-key".path;
        ssh_user = "btrbk";
        volume = {
          "/.btrfs-fsroot" = {
            snapshot_dir = "@snapshots";
            subvolume = {
              "@home" = { };
              "@masterdata" = { };
            };
          };
        };
      };
    };
  };

  # programs.mangowc = {
  #   enable = true;
  #   package = pkgs.unstable.mangowc;
  # };

  # programs.hyprland = {
  #   enable = false;
  #   withUWSM = true;
  #   xwayland.enable = false;
  # };
  # programs.hyprlock.enable = false;
  # services.hypridle.enable = false;

  # programs.firefox.enable = true;
  programs.firefox = {
    enable = true;

    languagePacks = [
      "en-US"
      "de"
      "ru"
    ];

    # doesn't work?
    preferences = {
      "mousewheel.with_alt.action" = 5;
      "ui.key.menuAccessKeyFocuses" = false;
    };

    policies = {
      # Updates & Background Services
      # AppAutoUpdate                 = false;
      # BackgroundAppUpdate           = false;

      # Feature Disabling
      # DisableBuiltinPDFViewer       = true;
      # DisableFirefoxStudies         = true;
      # DisableFirefoxAccounts        = true;
      # DisableFirefoxScreenshots     = true;
      # DisableForgetButton           = true;
      DisableMasterPasswordCreation = true;
      DisableProfileImport = true;
      # DisableProfileRefresh         = true;
      DisableSetDesktopBackground = true;
      DisablePocket = true;
      DisableTelemetry = true;
      # DisableFormHistory            = true;
      # DisablePasswordReveal         = true;

      # Access Restrictions
      # BlockAboutConfig              = false;
      # BlockAboutProfiles            = true;
      # BlockAboutSupport             = true;

      # UI and Behavior
      DisplayMenuBar = "never";
      DontCheckDefaultBrowser = true;
      HardwareAcceleration = true;
      OfferToSaveLogins = false;
      # DefaultDownloadDirectory      = "${home}/Downloads";

    };

    #    profiles.default.search = {
    #    # force           = true;
    #    # default         = "DuckDuckGo";
    #    # privateDefault  = "DuckDuckGo";
    #
    #    engines = {
    #      "Nix Packages" = {
    # urls = [
    #   {
    #     template = "https://search.nixos.org/packages";
    #     params = [
    #       { name = "channel"; value = "unstable"; }
    #       { name = "query";   value = "{searchTerms}"; }
    #     ];
    #   }
    # ];
    # icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    # definedAliases = [ "@np" ];
    #      };
    #
    #      "Nix Options" = {
    # urls = [
    #   {
    #     template = "https://search.nixos.org/options";
    #     params = [
    #       { name = "channel"; value = "unstable"; }
    #       { name = "query";   value = "{searchTerms}"; }
    #     ];
    #   }
    # ];
    # icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    # definedAliases = [ "@no" ];
    #      };
    #
    #      "NixOS Wiki" = {
    # urls = [
    #   {
    #     template = "https://wiki.nixos.org/w/index.php";
    #     params = [
    #       { name = "search"; value = "{searchTerms}"; }
    #     ];
    #   }
    # ];
    # icon           = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    # definedAliases = [ "@nw" ];
    #      };
    #    };
    #  };
  };

  # nixpkgs.config.allowBroken = true;
  # Allow unstable packages.
  # nixpkgs.config = {
  #   allowUnfree = true;
  #   packageOverrides = pkgs: {
  #     unstable = import <nixpkgs-unstable> {
  #       config = config.nixpkgs.config;
  #     };
  #   };
  # };

  # Allow unstable packages without relying on local nix-channel state
  # nixpkgs.config = {
  #   allowUnfree = true;
  #   packageOverrides = pkgs: {
  #     unstable = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {
  #       config = config.nixpkgs.config;
  #     };
  #   };
  # };

  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides =
      pkgs:
      let
        unstablePkgs = import unstable-src {
          config = config.nixpkgs.config;
        };
      in
      {
        unstable = unstablePkgs;

        # THE FIX: This goes inside the curly braces of the packageOverrides block
        # dgop = unstablePkgs.dgop;

        # Inject agenix from the downloaded tarball directly into the pkgs namespace
        # agenix = (import agenix-src { inherit pkgs; }).agenix;

        # Wrapped to automatically use the system identity key to avoid manually typing --identity
        agenix = pkgs.writeShellScriptBin "agenix" ''
          exec ${
            (import agenix-src { inherit pkgs; }).agenix
          }/bin/agenix -i /etc/ssh/ssh_host_ed25519_key "$@"
        '';
      };
  };
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    substituters = [ "https://devenv.cachix.org" ];
    trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];
    trusted-users = [
      "root"
      "izvyk"
    ];
  };

  services.xserver.enable = false;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.gnome.core-apps.enable = false;
  services.gnome.core-developer-tools.enable = false;
  services.gnome.games.enable = false;
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
  ];
  services.gnome.sushi.enable = true;
  services.gnome.gnome-online-accounts.enable = true;
  # services.gnome.gnome-keyring.enable = lib.mkDefault false;

  # services.fprintd.enable = true;

  programs.dconf.profiles.user.databases = [
    {
      lockAll = true; # prevents overriding
      settings = {
        "org/gnome/desktop/input-sources" = {
          # xkb-options = [
          #   "caps:escape_shifted_capslock"
          #   "ctrl:swap_lalt_lctl"
          # ];
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
        "org/gnome/mutter" = {
          experimental-features = [
            "scale-monitor-framebuffer" # Enables fractional scaling (125% 150% 175%)
            "variable-refresh-rate" # Enables Variable Refresh Rate (VRR) on compatible displays
            "xwayland-native-scaling" # Scales Xwayland applications to look crisp on HiDPI screens
          ];
          workspaces-only-on-primary = false;
        };
        "org/gnome/desktop/interface" = {
          show-battery-percentage = true;
          clock-show-seconds = true;
        };
        "org/gnome/settings-daemon/plugins/power".power-button-action = "nothing";
        "org/gnome/shell/app-switcher".current-workspace-only = true;
        "org/gnome/desktop/break-reminders".selected-breaks = [
          "eyesight"
          # "movement"
        ];
        # "org/gnome/desktop/break-reminders/movement" = {
        #   interval-seconds = lib.gvariant.mkUint32 3600;
        #   play-sound = false;
        # };
        "org/gnome/desktop/screensaver".lock-delay = lib.gvariant.mkUint32 30;
        "system/locale".region = "de_DE.UTF-8";
        "org/gnome/desktop/privacy" = {
          remove-old-trash-files = true;
          remove-old-temp-files = true;
          recent-files-max-age = lib.gvariant.mkInt32 30;
        };
        "org/gnome/desktop/wm/preferences/button-layout".appmenu = [
          "minimize"
          "close"
        ];

        "org/gnome/desktop/wm/keybindings".cycle-windows = [ "<Control>grave" ];
        "org/gnome/desktop/wm/keybindings".cycle-windows-backward = [ "<Shift><Control>grave" ];
        "org/gnome/desktop/wm/keybindings".switch-windows = [ "<Control>Tab" ];
        "org/gnome/desktop/wm/keybindings".switch-windows-backward = [ "<Shift><Control>Tab" ];
        "org/gnome/desktop/wm/keybindings".close = [ "<Super>q" ];


	# To avoid confusions when switching between iqunix keyboard and laptop keyboard
        "org/gnome/desktop/wm/keybindings".maximize = [ "<Super>k" ];
        "org/gnome/desktop/wm/keybindings".unmaximize = [ "<Super>j" ];
        "org/gnome/mutter/keybindings".toggle-tiled-left = [ "<Super>h" ];
        "org/gnome/mutter/keybindings".toggle-tiled-right = [ "<Super>l" ];
        "org/gnome/desktop/wm/keybindings".minimize = [ "<Super>m" ];


        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0".binding = "<Super>Return";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0".command = "footclient";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0".name = "Terminal";

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1".binding = "Launch5";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1".command =
          "/home/izvyk/.local/bin/volume-down";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1".name = "Volume down F14";

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2".binding = "Launch6";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2".command =
          "/home/izvyk/.local/bin/volume-up";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2".name = "Volume up F15";

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3".binding = "Launch7";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3".command =
          "/home/izvyk/.local/bin/brightness-down";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3".name =
          "Brightness down F16";

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4".binding = "Launch8";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4".command =
          "/home/izvyk/.local/bin/brightness-up";
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4".name =
          "Brightness up F17";

        "org/gnome/settings-daemon/plugins/media-keys".custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
        ];

        # "org/gnome/shell/keybindings".screenshot = "Insert";
        # "org/gnome/shell/keybindings".show-screenshot-ui = "<Shift>Insert";
        # "org/gnome/shell/keybindings".screenshot-window = "<Control>Insert";

        "org/gnome/desktop/wm/preferences".focus-mode = "sloppy";

        "org/gnome/desktop/interface".enable-hot-corners = false;

        # "org/gnome/shell/extensions/simplebreakreminder".time-between-breaks = lib.gvariant.mkUint32 60;

        "org/gnome/shell/extensions/display-brightness-ddcutil".show-all-slider = true;
        "org/gnome/shell/extensions/display-brightness-ddcutil".show-sliders-in-submenu = true;

        "org/gnome/shell/extensions/clipboard-indicator".excluded-apps = [
          "KeePassXC"
          "org.keepassxc.KeePassXC"
        ];

        # "org/gnome/shell/extensions/just-perfection".search = false;
        "org/gnome/shell/extensions/just-perfection".top-panel-position = lib.gvariant.mkInt32 1;
        "org/gnome/shell/extensions/just-perfection".dash = false;
        "org/gnome/shell/extensions/just-perfection".activities-button = false;

        "org/gnome/desktop/interface".accent-color = "teal";
        "org/gnome/settings-daemon/plugins/color".night-light-enabled = true;

        "org/gnome/shell" = {
          disable-user-extensions = false;
          disable-extension-version-validation = true;

          # disabled-extensions = [];

          enabled-extensions = [
            # "gnomeExtensions.paperwm"
            "caffeine@patapon.info"
            "clipboard-indicator@tudmotu.com"
            "disconnect-wifi@kgshank.net"
            "display-brightness-ddcutil@themightydeity.github.com"
            "do-not-disturb-while-screen-sharing-or-recording@marcinjahn.com"
            "gsconnect@andyholmes.github.io"
            # "simplebreakreminder@castillodel.com"
            "middleclickclose@paolo.tranquilli.gmail.com"
            "panel-corners@aunetx"
            "just-perfection-desktop@just-perfection"
          ];
        };
      };
    }
  ];

  programs.fish.enable = true;
  # Tell direnv to hook into your fish shell
  programs.fish.interactiveShellInit = ''
    direnv hook fish | source
  '';
  environment.pathsToLink = [
    "/share/nix-direnv"
  ];
  environment.systemPackages = with pkgs; [
    #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #   wget
    linux-firmware
    neovim
    bat
    btop
    zoxide
    file
    nixfmt
    ddcutil

    nautilus
    gparted
    exfat

    cryptsetup

    direnv
    nix-direnv

    # dae

    # gnomeExtensions.paperwm
    gnomeExtensions.caffeine
    gnomeExtensions.brightness-control-using-ddcutil
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.disconnect-wifi
    gnomeExtensions.do-not-disturb-while-screen-sharing-or-recording
    gnomeExtensions.gsconnect
    gnomeExtensions.panel-corners
    gnomeExtensions.just-perfection
    gnomeExtensions.middle-click-to-close-in-overview
    # gnomeExtensions.simple-break-reminder

    agenix

    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav

    easyeffects
    android-tools
  ];

  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  # services.keyd = {
  #   enable = true;
  #   keyboards = {
  #     default = {
  #       ids = [ "*" ];
  #       settings = {
  #         main = {
  #           leftcontrol = "layer(alt)";
  #           leftalt = "layer(control)";
  #         };
  #       };
  #     };
  #   };
  # };

  hardware.uinput.enable = true;

  services.keyd = {
    enable = true;
    # package = pkgs.unstable.keyd;
    keyboards = {
      # ----------------------------------------------------
      # 1. LAPTOP & ALL OTHER KEYBOARDS
      # ----------------------------------------------------
      default = {
        ids = [
          "*"
          "-1050:*" # exclude Yubikeys
          "-0000:0006"
        ];
        settings = {
          main = sharedMain;
          space_layer = sharedSpaceLayer;
        };
      };

      # Mouse remaps (mouse -> logid -> keyd)
      mxmaster = {
        ids = [
          "0000:0000"
          "046d:c548"
        ];
        settings = {
          main = {
            # Thumb button
            "f20" = "overload(thumb_layer, layer(meta))";

            # Normal scroll wheel
            "f18" = "scrollup";
            "f19" = "scrolldown";

            # player controls on back/forward
            "mouse1" = "timeout(macro2(-1, 0, mouse1), 400ms, macro2(-1, 0, previoussong))";
            "mouse2" = "timeout(macro2(-1, 0, mouse2), 400ms, macro2(-1, 0, nextsong))";

            # Right mouse key as a layer trigger
            "rightmouse" = "overload(rightmouse_layer, rightmouse)";

            # Probably destructive
            # "leftmouse+rightmouse" = "f5";
          };

          "thumb_layer:A" = {
            # classic zoom
            "leftmouse" = "C-minus";
            "rightmouse" = "C-equal";
            "leftmouse+rightmouse" = "C-0";

            # touchpad-style zoom (e.g. in browsers)
            "f18" = "scrollup";
            "f19" = "scrolldown";

            # misc
            "middlemouse" = "f5";
            # "playpause" = "nextsong";

            # "rightmouse" = "overload(horizontalscroll_layer, C-equal)";
            # "leftmouse" = "overload(zoom_reset_left_layer, C-minus)";
            # "rightmouse" = "overload(zoom_reset_right_layer, C-equal)";
          };

          "rightmouse_layer" = {
            # horizontal scroll for the main wheel
            "f18" = "scrollleft";
            "f19" = "scrollright";

            # Brightness for thumb wheel
            "f14" = "f16";
            "f15" = "f17";

            "middlemouse" = "f5";
          };
        };
      };

      # ----------------------------------------------------
      # 2. EXTERNAL KEYBOARD (IQUNIX Magi 65)
      # ----------------------------------------------------
      external_iqunix = {
        ids = [
          "320f:5088"
        ];
        settings = {
          main = sharedMain // {
            home = "timeout(macro2(-1, 0, home), 250ms, macro2(-1, 0, f24))";
          };

          space_layer = sharedSpaceLayer // {
            "1" = "brightnessdown";
            "2" = "brightnessup";
            "7" = "previoussong";
            "8" = "playpause";
            "9" = "nextsong";
            "0" = "mute";
            "-" = "volumedown";
            "equal" = "volumeup";
          };
        };
      };
    };
  };

  services.udisks2.settings = {
    "mount_options.conf" = {
      defaults = {
        defaults = "noatime,noexec";
        # Example: Extra defaults specifically for BTRFS removable drives
        # btrfs_defaults = "noatime,compress=zstd";

        vfat_defaults = "noatime,noexec";
        exfat_defaults = "noatime,noexec";
        ntfs_defaults = "noatime,noexec";
        ext4_defaults = "noatime,noexec";
        btrfs_defaults = "noatime,noexec";
      };
    };
  };

  # environment.etc."crypttab".text = ''
  #   data UUID=526035a8-e49a-4b98-b79d-b74096ac51de /root/d.key bitlk
  # '';

  # fileSystems."/mnt/data" = {
  #   device = "/dev/mapper/data";
  #   fsType = "ntfs"; # Or "exfat", depending on the partition format
  #   options = [
  #     "rw"
  #     "uid=1000"
  #     "gid=100" # Make your user (usually 1000) the owner
  #     "umask=0022" # Ensure files are readable
  #     "nofail" # Don't crash boot if the drive is missing
  #     "x-gvfs-show" # <--- CRITICAL: Forces Nautilus to show it in Sidebar
  #     "x-gvfs-name=Data" # <--- Optional: Gives it a pretty name in Nautilus
  #
  #   ]; # Permission settings for NTFS
  # };

  #   programs.git = {
  #   enable = true;
  #
  #   signing = {
  #     key = "~/.ssh/yubikey.pub";
  #     signByDefault = true;
  #   };
  #
  #   extraConfig = {
  #     gpg = {
  #       format = "ssh";
  #     };
  #     "gpg \"ssh\"" = {
  #       program = "${pkgs.openssh}/bin/ssh-keygen"; # Helper program for signing
  #     };
  #   };
  # };

  programs.ssh.extraConfig = ''
    Match User root
      Host github.com
        User git
        IdentityFile /root/.ssh/ssh_ed25519_github
        IdentitiesOnly yes
  '';

  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  # In /etc/nixos/configuration.nix
  programs.git = {
    enable = true;

    # Use 'config' instead of 'extraConfig' for system-wide settings
    config = {
      gpg.format = "ssh";
      "gpg \"ssh\"".program = "${pkgs.openssh}/bin/ssh-keygen";

      # If you are setting up signing globally (be careful with this for multi-user systems)
      commit.gpgsign = true;
      user.signingkey = "~/.ssh/yubikey.pub"; # Ensure this path is valid for all users or use absolute paths
    };
  };

  programs.gnupg.agent.enableSSHSupport = false;
  services.yubikey-agent.enable = true;
  # security.pam = {
  #   u2f = {
  #     enable = true;
  #     settings = {
  #       # interactive = true;
  #       cue = true;
  #       cue_prompt = "⚡ Touch the device";
  #       authfile = "/etc/Yubico/u2f_keys";
  #       origin = "pam://philipp-XPS-13";
  #     };
  #     control = "required";
  #   };
  #
  #   services = {
  #     login.u2fAuth = true;
  #     doas.u2fAuth = true;
  #     quickshell.u2fAuth = true;
  #     hyprlock.u2fAuth = true;
  #   };
  # };

  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    NIXOS_OZONE_WL = "1";
    GST_PLUGIN_PATH = "/run/current-system/sw/lib/gstreamer-1.0/";
  };

  # # environment.etc = {
  # #   "Yubico/u2f_keys" = {
  # #     text = ''
  # #       izvyk:SYTl2m5FtwjzACS0rNJrPMf3NWNPvaql5u/4tzkhplp3MLRzzMhNL9LNssTB0Pxv1LI/8wZEG9Fli8lupEdCxg==,ptIzQnICwLd3CvGkaX5oIvRZxdZvH+j8wR1e1VzBuPvDbNoY8lOdeZuVUYzQgszhZTK+0ucJQ2byYIZLwD3E9Q==,es256,+presence:58m/39fqoOc0Iw+wONKDD9/twmvZHBCnYfrkCFuBrw2Ah5SbhaPvGvXmsNWStl11QemD7BIB4lPPiUzX6S3mDw==,++0tTVCPHQYUEfH7C15Q1EKvDchmOM6GVXI2KyZJA03wUMB6gkdTqhHhWUXX5ky5sy5aHldRmFvUE8CVaOTKYg==,es256,+presence:fPbiT2tGPgsWnUc/3Wv8gCH6OkiPcNQJ6baSJnD93yisiMYW7Z46YN9P0kSkcF9x+n2qTMOyPio5cabtlgLZaQ==,dFNN5D/qLUox3+l3lYqLaNQPA0qC/bmRPGr1dV2nCv/kYnpc+kjQ5kodQcFLxWhVWTnmlobtggmG2Qm+cIilUQ==,es256,+presence
  # #     '';
  # #     # text = ''
  # #     #   izvyk:sXVlvPJmpEtdynu1ayCHrRcv2nCGwNJB7JqcW3sS4Vs0p4qPlSkjQ9k06fpzN3+1vjZ8/tSJ9w/2l1uKF1X7cA==,nANpkTMqHfIkqhTpxyF+O1O7DjhR797tOHQrcQbHobDGUFyv7OKrimOaaTY7epmc4fvdGUrcDwg3LCLy22r1yw==,es256,+presence
  #     # '';
  #     mode = "0600";
  #   };
  # };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.iosevka
      open-sans
    ];

    fontconfig = {
      defaultFonts = {
        monospace = [ "Iosevka Nerd Font" ];
        # serif = [ "" ];
        sansSerif = [ "Open Sans" ];
      };
    };
  };
  services.gvfs.enable = true;
  programs.fuse.userAllowOther = true;

  # Age secrets configuration for syncthing
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  services.syncthing = {
    enable = true;
    user = "izvyk";
    group = "users";
    dataDir = "/home/izvyk"; # Default folder for new synced folders
    configDir = "/home/izvyk/.config/syncthing"; # Folder for Syncthing's settings and keys
    cert = config.age.secrets."syncthing-cert".path;
    key = config.age.secrets."syncthing-key".path;
  };

  age.secrets."syncthing-cert" = {
    file = ./secrets/syncthing-cert.age;
    owner = "izvyk";
    group = "users";
  };

  age.secrets."syncthing-key" = {
    file = ./secrets/syncthing-key.age;
    owner = "izvyk";
    group = "users";
  };

  services.resolved.enable = true;

  services.upower.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true; # Необходим для приоритезации аудио-потоков

  services.pipewire.extraConfig.pipewire."99-virtual-mic" = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "Pixel 8 Virtual Mic";
          "capture.props" = {
            "media.class" = "Audio/Sink";
            "audio.position" = [ "MONO" ];
          };
          "playback.props" = {
            "media.class" = "Audio/Source";
            "audio.position" = [ "MONO" ];
          };
        };
      }
    ];
  };

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      # swtpm.enable = true;      # optional, only if you want vTPM anyway
      # ovmf.enable = true;       # UEFI firmware
    };
  };

  programs.virt-manager.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  # };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  # environment.systemPackages = with pkgs; [
  #   vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #   wget
  # ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # services.dae = {
  #   enable = true;
  #   # Point to a file outside the Nix store to keep your V2Ray key secret
  #   configFile = "/etc/dae/config.dae";
  # };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  services.tailscale.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    # Always allow traffic from your Tailscale network
    trustedInterfaces = [ "tailscale0" ];
    # Allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # NixOS firewall will block wg traffic because of rpfilter
  networking.firewall.checkReversePath = "loose";

  # 2. Force tailscaled to use nftables (Critical for clean nftables-only systems)
  # This avoids the "iptables-compat" translation layer issues.
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # only enable manually when needed to save power & for security
    settings = {
      General = {
        # Явно разрешаем профили Source (отдавать звук) и Sink (принимать звук)
        Enable = "Source,Sink,Media,Socket";
        # Экспериментальный флаг часто необходим для включения расширенных кодеков
        # и передачи информации о заряде батареи
        # Experimental = true;
      };
    };
  };
  hardware.i2c.enable = true;
  hardware.brillo.enable = true;

  # Enable logid
  services.logiops = {
    enable = true;
    # package = pkgs.unstable.logiops;

    config = {
      devices = [
        {
          name = "MX Master 3S For Business";

          # Firmware level optimizations
          smartshift = {
            on = true;
            threshold = 10;
          };

          dpi = 1000;

          # hiresscroll = {
          #   hires = false;
          #   invert = false;
          #   target = false;
          # };

          hiresscroll = {
            hires = false;
            invert = false;
            target = true;
            up = {
              mode = "OnInterval";
              interval = 1;
              action = {
                type = "Keypress";
                keys = [ "KEY_F18" ];
              };
              # action = { type = "Keypress"; keys = [ "KEY_VOLUMEDOWN" ]; };
            };
            down = {
              mode = "OnInterval";
              interval = 1;
              action = {
                type = "Keypress";
                keys = [ "KEY_F19" ];
              };
              # action = { type = "Keypress"; keys = [ "KEY_VOLUMEUP" ]; };
            };
          };

          # Thumbwheel mapped directly to native OS volume hooks
          thumbwheel = {
            divert = true;
            invert = false;
            left = {
              mode = "OnInterval";
              interval = 1;
              action = {
                type = "Keypress";
                keys = [ "KEY_F14" ];
              };
              # action = { type = "Keypress"; keys = [ "KEY_VOLUMEDOWN" ]; };
            };
            right = {
              mode = "OnInterval";
              interval = 1;
              action = {
                type = "Keypress";
                keys = [ "KEY_F15" ];
              };
              # action = { type = "Keypress"; keys = [ "KEY_VOLUMEUP" ]; };
            };
          };

          buttons = [
            # The Thumb Gesture Button
            {
              cid = 195;
              action = {
                type = "Keypress";
                keys = [ "KEY_F20" ];
              };
              # action = {
              #   type = "Gestures";
              #   gestures = [
              #     {
              #       direction = "Down";
              #       mode = "OnRelease";
              #       action = { type = "Keypress"; keys = [ "KEY_F5" ]; };
              #     }
              #     # {
              #     #   direction = "None";
              #     #   mode = "OnRelease";
              #     #   action = { type = "Keypress"; keys = [ "KEY_F20" ]; };
              #     #   # action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" ]; };
              #     # }
              #   ];
              # };
            }

            # The Top Button: Media Play/Pause
            {
              cid = 196;
              action = {
                type = "Keypress";
                keys = [ "KEY_PLAYPAUSE" ];
              };
            }
          ];
        }
      ];
    };
  };

  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      {
        groups = [ "wheel" ];
        # keepEnv = true;
        persist = true;
        # Explicitly whitelist ONLY what is safe and necessary
        setEnv = [
          "COLORTERM"
          "TERM"
          "EDITOR"
          "PAGER"
          # "SSH_AUTH_SOCK" # Uncomment if you need user SSH keys as root
        ];
      }
    ];
  };

  services.nohang = {
    enable = true;
    # package = pkgs.unstable.nohang;
    # enableDesktopNotifications = true; # is implied in NixOS when enable = true for nohang package
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100; # Maximum priority. Kernel uses this first.
  };

  # Dynamically allocate the physical swapfile ONLY during hibernation lifecycles.
  # The swapfile is completely invisible to the kernel during normal runtime.
  systemd.services.systemd-hibernate.serviceConfig = {
    ExecStartPre = "-${pkgs.util-linux}/bin/swapon /swap/swapfile";
    ExecStopPost = "-${pkgs.util-linux}/bin/swapoff /swap/swapfile";
  };

  systemd.services.systemd-suspend-then-hibernate.serviceConfig = {
    ExecStartPre = "-${pkgs.util-linux}/bin/swapon /swap/swapfile";
    ExecStopPost = "-${pkgs.util-linux}/bin/swapoff /swap/swapfile";
  };

  systemd.services.systemd-logind = {
    environment = {
      SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK = "1";
    };
  };

  # environment.etc."systemd/system-sleep/swap-for-hibernate" = {
  #   text = ''
  #     #!/bin/sh
  #     echo $1/$2
  #     case "$1/$2" in
  #       pre/hibernate|pre/hybrid-sleep)
  # 	/run/current-system/sw/bin/swapon /swap/swapfile
  # 	;;
  #       post/hibernate|post/hybrid-sleep)
  # 	/run/current-system/sw/bin/swapoff /swap/swapfile
  # 	;;
  #     esac
  #   '';
  #   mode = "0755";
  # };

  # Limit nix rebuilds priority.  When left on the default is uses all available resources which can make the system unusable
  nix = {
    settings.cores = 6;
    # daemonCPUSchedPolicy = "idle";
    # daemonIOSchedClass = "idle";
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspendThenHibernate = "yes";
    HibernateOnACPower = "yes";
    HibernateDelaySec = "30m";
  };

  # powerManagement.powertop.enable = true;
  powerManagement.enable = true;
  # powerManagement.cpuFrequencyGovernor = "powersave";

  # Enable auto-upgrades.
  system.autoUpgrade = {
    enable = false;
    # Run daily
    dates = "daily";
    # Build the new config and make it the default, but don't switch yet.  This will be picked up on reboot.  This helps
    # prevent issues with OpenSnitch configs not well matching the state of the system.
    operation = "boot";
  };

  services.fwupd.enable = true;

  services.udev.packages = [
    pkgs.via
    # pkgs.brillo
  ];
  services.udev.extraRules = ''
    # Mouse
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c53f", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"

    # Keyboard
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="320f", ATTR{idProduct}=="5088", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"

    # USB-Hub
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="214b", ATTR{idProduct}=="7260", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"
  '';

  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    # Uses the exact rule set maintained by the CachyOS community
    rulesProvider = pkgs.ananicy-rules-cachyos;
    settings = {
      apply_cgroup = false;
      cgroup_load = false;
      cgroup_realtime_workaround = lib.mkForce false;
    };
  };

  systemd.settings.Manager.RebootWatchdogSec = "0";

  boot = {
    resumeDevice = "/dev/mapper/cryptroot";
    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = 0;
    loader = {
      timeout = 0;
      systemd-boot.enable = true;
      systemd-boot.consoleMode = "keep";
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      verbose = false;
      systemd.enable = true;
      compressor = "${pkgs.zstd}/bin/zstd -19 -T0";
    };
    kernel.sysctl = {
      # SysRq: enable F R E I S U B
      "kernel.sysrq" = 244;

      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";

      # ---------------------------------------------------------------------
      # ZRAM-Specific Tuning
      # ---------------------------------------------------------------------

      # Myth: "Lower swappiness prevents disk IO."
      # Reality: With ZRAM, swap is highly compressed RAM.
      # If you set swappiness to 10, the kernel will aggressively drop your filesystem
      # cache (file reads, application binaries) to avoid swapping. When you switch
      # back to an application, the system stalls while re-reading those files from the NVMe.
      # Setting this to 100+ tells the kernel: "Compressing memory is cheaper than disk IO.
      # Keep the file cache alive and compress idle application memory instead."
      "vm.swappiness" = 150;

      # Read-ahead relies on physical disk geometry. When reading from a spinning disk
      # or NVMe, pulling contiguous blocks is faster. ZRAM is not a disk.
      # ZRAM is compressed memory chunks. Reading ahead in ZRAM wastes CPU cycles
      # decompressing pages you haven't even asked for yet. Disable it.
      "vm.page-cluster" = 0;

      # ---------------------------------------------------------------------
      # Memory Allocator & Desktop Latency
      # ---------------------------------------------------------------------

      # This controls the distance between the kernel waking up `kswapd` (background
      # memory reclaimer) and hitting the absolute limit (OOM).
      # Default is 10 (0.1% of RAM). If an application suddenly asks for 1GB of RAM,
      # a low watermark means the kernel is caught off guard, stalls the application,
      # and furiously frees memory.
      # 125 (1.25%) keeps a larger buffer of free RAM ready, preventing micro-stutters
      # during sudden workload spikes.
      "vm.watermark_scale_factor" = 125;

      # Proactively compact memory in the background. Prevents the kernel from
      # struggling to find contiguous memory blocks (like when a VM requests hugepages)
      # at the cost of a tiny amount of idle CPU time. 20 is a sane modern default,
      # keep it explicit.
      "vm.compaction_proactiveness" = 20;

      # ---------------------------------------------------------------------
      # Writeback IO / BTRFS Stutter Prevention
      # ---------------------------------------------------------------------

      # When you save large files or download at gigabit speeds, Linux caches the
      # writes in RAM ("dirty pages"). Default dirty_ratio is 20%.
      # On a 16GB system, the kernel might buffer 3.2GB of writes in RAM.
      # When it finally flushes to the NVMe, especially on BTRFS, it locks up the
      # filesystem queue. The entire desktop can freeze for seconds.
      # We lower these ratios to force the kernel to trickle-write data continuously
      # in the background, keeping the IO queue clear and the desktop responsive.

      # Start writing dirty pages to disk in the background when they hit 5% of RAM.
      # "vm.dirty_background_ratio" = 5;
      "vm.dirty_background_bytes" = 268435456; # 256MB

      # Force synchronous IO (block the application from writing more) if dirty pages
      # somehow hit 10%. Prevents uncontrollable IO debt.
      "vm.dirty_bytes" = 536870912; # 512MB
    };
    kernelParams = [
      "resume_offset=92460818"
      "quiet"
      # "bgrt_disable"
      "loglevel=3"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "iwlwifi.power_save=1"
      "iwlmvm.power_scheme=3"
      "nmi_watchdog=0"
      "tsc=unstable"
    ];
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}
