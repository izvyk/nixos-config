# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  # 1. Fetch the unstable tarball and assign its path to a variable
  # unstable-src = fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  agenix-src = fetchTarball "https://github.com/ryantm/agenix/archive/main.tar.gz";
in
{
  _module.args.username = "izvyk";

  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./gnome.nix
    ./dock-mode.nix
    ./input.nix
    ./home-manager.nix
    ./network.nix

    # "${unstable-src}/nixos/modules/programs/wayland/mangowc.nix"
    # "${unstable-src}/nixos/modules/services/system/nohang.nix"

    "${agenix-src}/modules/age.nix"
  ];

  # This tells NixOS to skip loading its default versions of these modules
  # disabledModules = [
  #   # "programs/wayland/mangowc.nix"
  # ];

  systemd.services.libvirtd.wantedBy = lib.mkForce [ ]; # no autostart but keep socket activation

  systemd.services.systemd-user-sessions.unitConfig.After = [
    "remote-fs.target"
    "nss-user-lookup.target"
    "home.mount"
  ];

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

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
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
        # unstablePkgs = import unstable-src {
        #   config = config.nixpkgs.config;
        # };
      in
      {
        # unstable = unstablePkgs;
        unstable = import <nixpkgs-unstable> {
          config = pkgs.config;
        };

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
      # "${username}"
    ];
  };

  services.xserver.enable = false;

  xdg.terminal-exec = {
    enable = true;
    settings = {
      GNOME = [ "com.mitchellh.ghostty.desktop" ];
      default = [ "com.mitchellh.ghostty.desktop" ];
    };
  };

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "firefox.desktop" ];
    };
  };

  programs.fish.enable = true;
  # Tell direnv to hook into your fish shell
  programs.fish.interactiveShellInit = ''
    direnv hook fish | source
  '';
  environment.pathsToLink = [
    "/share/nix-direnv"
  ];
  environment.systemPackages = with pkgs; [
    linux-firmware
    bat
    btop
    zoxide
    file
    nixfmt
    ddcutil

    cryptsetup

    direnv
    nix-direnv

    # dae

    agenix

    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav

    tmux

    nix-index
    android-tools

    man-pages # Provides Linux programmer's manual
    man-pages-posix # Optional, but highly recommended for standard POSIX API docs
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  hardware.uinput.enable = true;

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
  # #       ${username}:SYTl2m5FtwjzACS0rNJrPMf3NWNPvaql5u/4tzkhplp3MLRzzMhNL9LNssTB0Pxv1LI/8wZEG9Fli8lupEdCxg==,ptIzQnICwLd3CvGkaX5oIvRZxdZvH+j8wR1e1VzBuPvDbNoY8lOdeZuVUYzQgszhZTK+0ucJQ2byYIZLwD3E9Q==,es256,+presence:58m/39fqoOc0Iw+wONKDD9/twmvZHBCnYfrkCFuBrw2Ah5SbhaPvGvXmsNWStl11QemD7BIB4lPPiUzX6S3mDw==,++0tTVCPHQYUEfH7C15Q1EKvDchmOM6GVXI2KyZJA03wUMB6gkdTqhHhWUXX5ky5sy5aHldRmFvUE8CVaOTKYg==,es256,+presence:fPbiT2tGPgsWnUc/3Wv8gCH6OkiPcNQJ6baSJnD93yisiMYW7Z46YN9P0kSkcF9x+n2qTMOyPio5cabtlgLZaQ==,dFNN5D/qLUox3+l3lYqLaNQPA0qC/bmRPGr1dV2nCv/kYnpc+kjQ5kodQcFLxWhVWTnmlobtggmG2Qm+cIilUQ==,es256,+presence
  # #     '';
  # #     # text = ''
  # #     #   ${username}:sXVlvPJmpEtdynu1ayCHrRcv2nCGwNJB7JqcW3sS4Vs0p4qPlSkjQ9k06fpzN3+1vjZ8/tSJ9w/2l1uKF1X7cA==,nANpkTMqHfIkqhTpxyF+O1O7DjhR797tOHQrcQbHobDGUFyv7OKrimOaaTY7epmc4fvdGUrcDwg3LCLy22r1yw==,es256,+presence
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
    user = username;
    group = "users";
    dataDir = "/home/${username}"; # Default folder for new synced folders
    configDir = "/home/${username}/.config/syncthing"; # Folder for Syncthing's settings and keys
    cert = config.age.secrets."syncthing-cert".path;
    key = config.age.secrets."syncthing-key".path;
  };

  age.secrets."syncthing-cert" = {
    file = ./secrets/syncthing-cert.age;
    owner = username;
    group = "users";
  };

  age.secrets."syncthing-key" = {
    file = ./secrets/syncthing-key.age;
    owner = username;
    group = "users";
  };

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:


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

  security.sudo.enable = false;
  security.doas = {
    enable = true;
    extraRules = [
      {
        groups = [ "wheel" ];
        persist = true;
        setEnv = [
          "-SSH_AUTH_SOCK" # doas.nix module adds this by default. We don't want user's SSH agent to leak into root's environment
          "COLORTERM"
        ];
      }
      # {
      #   noPass = true;
      #   users = [ username ];
      #   cmd = "${snapshotScript}/bin/agent-snapshot";
      # }
    ];
  };

  services.nohang = {
    enable = true;
    # package = pkgs.unstable.nohang;
  };
  # Inject sudo shim into the systemd service environment
  systemd.services.nohang.path = [
    (pkgs.writeShellScriptBin "sudo" ''
      exec ${pkgs.doas}/bin/doas "$@"
    '')
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100; # Maximum priority. Kernel uses this first.
  };

  # Dynamically allocate the physical swapfile ONLY during hibernation lifecycles.
  # The swapfile is completely invisible to the kernel during normal runtime.
  systemd.services.systemd-hibernate.serviceConfig = {
    ExecStartPre = "${pkgs.util-linux}/bin/swapon /swap/swapfile";
    ExecStopPost = "${pkgs.util-linux}/bin/swapoff /swap/swapfile";
  };

  systemd.services.systemd-suspend-then-hibernate.serviceConfig = {
    ExecStartPre = "${pkgs.util-linux}/bin/swapon /swap/swapfile";
    ExecStopPost = "${pkgs.util-linux}/bin/swapoff /swap/swapfile";
  };

  systemd.services.systemd-logind = {
    environment = {
      SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK = "1";
    };
  };
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    # lidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    # HandleSuspendKey = "suspend-then-hibernate";
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
    HibernateDelaySec = "2h";
    HibernateMode = "shutdown";
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
      "kernel.softlockup_panic" = 1; # panic on soft lockup, not just log it
      "kernel.panic" = 10; # auto-reboot 10s after any panic
      "kernel.panic_on_oops" = 1; # panic on detected memory corruption

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
