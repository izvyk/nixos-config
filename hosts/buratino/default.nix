# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  username = "phil";
  server-ts = "tortila.shorthair-inconnu.ts.net";
  server-ssh-pub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPI3xUUvndkvdm2DiHKAl+7pu6D9k3WsrPwLyfBHpTe";
in
{
  _module.args.username = username;

  imports = [
    ./hardware-configuration.nix
    ./gnome.nix
    ./dock-mode.nix
    ./input.nix
    ./home-manager.nix
    ./network.nix
    ./virtualisation.nix
    ./hibernate-prep.nix
    ./secure-boot.nix
    ../../modules/neovim.nix
    ../../modules/upd.nix
    ../../modules/nixpkgs-overlay.nix

    # fontconfig.aliases only exists in unstable
    "${inputs.nixpkgs-unstable}/nixos/modules/config/fonts/fontconfig.nix"

    inputs.agenix.nixosModules.default
    # nix-locate and fish's command-not-found hint, with a prebuilt database.
    inputs.nix-index-database.nixosModules.nix-index
  ];

  disabledModules = [
    "config/fonts/fontconfig.nix"
  ];


  time.timeZone = "Europe/Berlin";

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

  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "video"
    ];
  };

  age.secrets."btrbk-ssh-key" = {
    file = ../../secrets/btrbk-ssh-key.age;
    owner = "btrbk";
    group = "btrbk";
    mode = "0400";
  };

  programs.ssh.knownHosts.server = {
    extraHostNames = [
      "tortila.lan"
      "${server-ts}"
    ];
    publicKey = "${server-ssh-pub}";
  };

  services.btrbk = {
    instances.home = {
      onCalendar = "hourly";
      settings = {
        # Create snapshots only. Do not prune shared snapshots here.
        snapshot_preserve_min = "all";
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
    instances.offsite = {
      onCalendar = "*-*-* 21:00:00";
      settings = {
        snapshot_create = "no";

        # Source retention, applied only after a successful offsite run.
        snapshot_preserve_min = "3d";
        snapshot_preserve = "2w 2m";

        target_preserve_min = "no";
        target_preserve = "3d 2w 2m";

        ssh_identity = config.age.secrets."btrbk-ssh-key".path;
        ssh_user = "btrbk";
        send_compressed_data = "yes";
        send_protocol = "2";
        stream_buffer_remote = "256m";
        volume."/.btrfs-fsroot" = {
          snapshot_dir = "@snapshots";
          subvolume."@home".target = "ssh://${server-ts}/backup/laptop";
          subvolume."@masterdata".target = "ssh://${server-ts}/backup/masterdata";
        };
      };
    };
  };

  # The timer catches up at boot and on resume, before tailnet DNS may work.
  # Retry for half an hour, then wait for the next timer run.
  systemd.services.btrbk-offsite = {
    after = [ "tailscaled.service" ];
    startLimitIntervalSec = 3600;
    startLimitBurst = 6;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5min";
    };
  };

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

  nixpkgs.config = {
    allowUnfree = true;
  };

  # Keep one rebuild below the 6c/12t laptop's interactive workload.  Four
  # build threads leave room for GNOME, the browser, and memory compression.
  nix = {
    settings = {
      cores = 4;
      max-jobs = 1;

      auto-optimise-store = true;
      # Fallback to the weekly gc below: when a build sees under 10 GiB free,
      # collect garbage until 30 GiB are free. Only unreferenced paths go;
      # generations stay.
      min-free = 10 * 1024 * 1024 * 1024;
      max-free = 30 * 1024 * 1024 * 1024;
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      tarball-ttl = 86400;
      substituters = [ "https://devenv.cachix.org" ];
      trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];
      trusted-users = [
        "root"
        # "${username}"
      ];
    };
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
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
  environment.shellAliases = lib.mkForce {}; # Don't add aliases to the shell
  # direnv with nix-direnv; the fish hook is in chezmoi (portable).
  programs.direnv = {
    enable = true;
    enableFishIntegration = false;
  };
  # `, <cmd>`: run a program from nixpkgs without installing it; finds the
  # package via the nix-index database (imported above).
  programs.nix-index-database.comma.enable = true;
  environment.systemPackages = with pkgs; [
    # `,, <cmd>`: the same from nixpkgs-unstable (like `nsu` next to `ns`).
    # comma ignores -F whenever NIX_PATH has nixpkgs= (ours does), so point
    # <nixpkgs> at unstable instead, like `nsu` does with -I.
    # comma's cache is keyed by command name only, so `,` and `,,` would
    # hand each other's binaries back; `,,` doesn't use it at all.
    # Store paths can't contain commas, hence the separate package name.
    (writeTextFile {
      name = "comma-unstable";
      destination = "/bin/,,";
      executable = true;
      text = ''
        #!${runtimeShell}
        NIX_PATH=nixpkgs=channel:nixpkgs-unstable COMMA_CACHING=0 exec , "$@"
      '';
    })
    # `updf`: update flake.lock in the checkout, commit and push it, then `upd`
    # (modules/upd.nix) to build and deploy it.
    (writeShellApplication {
      name = "updf";
      runtimeInputs = [
        git
        config.nix.package
      ];
      text = ''
        repo=~/Projects/nixos-config
        git -C "$repo" pull --ff-only
        nix flake update --flake "$repo"
        # Commit whenever flake.lock differs from HEAD, not only when this run
        # changed it, so a commit that failed last time (key not touched) is
        # retried.
        if ! git -C "$repo" diff --quiet HEAD -- flake.lock; then
          git -C "$repo" commit -m "flake.lock: update" -- flake.lock
        fi
        git -C "$repo" push
        exec upd
      '';
    })
    linux-firmware
    bat
    btop
    zoxide
    file
    nixfmt

    cryptsetup
    exfatprogs
    f2fs-tools

    agenix

    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav

    tmux
    gparted

    unstable.android-tools

    man-pages # Provides Linux programmer's manual
    man-pages-posix # Optional, but highly recommended for standard POSIX API docs
  ];

  hardware.uinput.enable = true;

  services.udisks2.settings = {
    "mount_options.conf" = {
      defaults = {
        defaults = "noatime,noexec";
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

  # Keep Git's personal identity and signing policy in user-space.  The
  # system only provides the program; it must not depend on a user's home.
  programs.git.enable = true;

  programs.gnupg.agent.enableSSHSupport = false;
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
    # The T3 Code app forwards this to its local backend; that backend only
    # runs until the local environment is switched off (agents run on tortila).
    T3CODE_TELEMETRY_ENABLED = "false";
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
    fontDir.enable = true;
    enableDefaultPackages = false;
    packages = with pkgs; [
      # Sans-Serif
      # geist-font # достаточно "незаметный"
      (google-fonts.override {
        fonts = [ "Roboto Condensed" ];
      })
      # (iosevka-bin.override { variant = "Aile"; }) # Смотрится по-технически, сухо - это минус
      # ibm-plex # Sans Condensed красивый, но кириллица отображается криво - ударения и буква Ж, проблемы с шириной букв

      # Serif
      literata # Красивый, легко читается, в меру нарядный, "мягкий", со сложными утолщениями и изгибами в качестве засечек
      # merriweather # Аккуратный, легко читается, "острый", c простыми, буквальными засечками
      (iosevka-bin.override { variant = "Etoile"; }) # Смотрится по-технически, как советская инструкция, напечатанная на машинке

      # Monospace
      (iosevka-bin.override { variant = "Curly"; }) # Идеален дял терминала, прекрасен во всём. Пробую Curly-вариант
      # nerd-fonts.iosevka

      # Emoji
      (pkgs.callPackage ./apple-emoji.nix { }) # Неподражаемые Apple Emoji!

      # Fallback
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
    ];

    fontconfig = {
      defaultFonts = {
        sansSerif = [
          "Roboto Condensed"

          "Noto Sans"
          "Noto Sans CJK JP"
          "Symbols Nerd Font"
        ];
        serif = [
          "Literata"
          "Merriweather"

          "Noto Serif"
          "Noto Serif CJK JP"
          "Symbols Nerd Font"
        ];
        monospace = [
          "Iosevka Curly"

          "Symbols Nerd Font"
          "Noto Sans" # Last resort
        ];
        emoji = [ "Apple Emoji" ];
      };

      aliases = {
        "ui-monospace".prefer = [ "Iosevka" ];
        "system-ui".prefer = [ "Roboto Condensed" ];
        "ui-serif".prefer = [ "Literata" ];
        "ui-rounded".prefer = [ "Roboto Condensed" ];
      };
    };
  };

  services.gvfs.enable = true;
  # programs.fuse.userAllowOther = true;

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
    file = ../../secrets/syncthing-cert.age;
    owner = username;
    group = "users";
  };

  age.secrets."syncthing-key" = {
    file = ../../secrets/syncthing-key.age;
    owner = username;
    group = "users";
  };

  services.upower.enable = true;

  services.geoclue2.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true; # Необходим для приоритезации аудио-потоков

  # PipeWire's X11 bell module was the only X client at login, so it started
  # Xwayland in the greeter and in the session, and crashed the greeter's
  # PipeWire when that Xwayland went away. Xwayland still starts on demand
  # when an X app connects.
  services.pipewire.extraConfig.pipewire."10-no-x11-bell"."context.properties"."module.x11.bell" =
    false;

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


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # only enable manually when needed to save power & for security
    settings = {
      General = {
        # Явно разрешаем профили Source (отдавать звук) и Sink (принимать звук)
        Enable = "Source,Sink,Media,Socket";
        # Экспериментальный флаг часто необходим для включения расширенных кодеков
        # и передачи информации о заряде батареи
        Experimental = true;
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

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    # lidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    # HandleSuspendKey = "suspend-then-hibernate";
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

    # Mouse: no wakeup
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", DRIVERS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c548", ATTR{power/wakeup}="disabled"
  '';

  systemd.tmpfiles.rules = [
    "w /sys/fs/btrfs/c044a7d1-a674-4dac-a9c8-14399829ebe4/allocation/data/dynamic_reclaim  - - - - 1"
    "w /sys/fs/btrfs/c044a7d1-a674-4dac-a9c8-14399829ebe4/allocation/data/periodic_reclaim - - - - 1"
    "w /sys/fs/btrfs/c044a7d1-a674-4dac-a9c8-14399829ebe4/allocation/metadata/dynamic_reclaim  - - - - 1"
    "w /sys/fs/btrfs/c044a7d1-a674-4dac-a9c8-14399829ebe4/allocation/metadata/periodic_reclaim - - - - 1"
    # Hibernation copies memory within RAM, which fails above ~7.7 GiB. The copy
    # ends up 1.5-3 GiB over this target, so the 5.9 GiB default is too high.
    "w /sys/power/image_size - - - - 3758096384"
  ];

  systemd.settings.Manager.RebootWatchdogSec = "0";

  # After 5 mount-table changes in a second (the upstream default), systemd
  # holds every mount job until that second ends. Boot here makes more than
  # that, so /sysroot/nix, the local mounts, /run/wrappers and the /boot
  # automount each waited about 1 s, 3.5 s per boot in all. 50 still caps
  # how often a mount storm can make PID 1 reread the mount table.
  systemd.managerEnvironment.SYSTEMD_DEFAULT_MOUNT_RATE_LIMIT_BURST = "50";
  boot.initrd.systemd.managerEnvironment.SYSTEMD_DEFAULT_MOUNT_RATE_LIMIT_BURST = "50";

  boot = {
    resumeDevice = "/dev/mapper/cryptroot";
    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = 0;
    zswap.enable = true;
    loader = {
      timeout = 0;
      # lanzaboote (secure-boot.nix) installs systemd-boot and takes these
      # settings.
      systemd-boot.consoleMode = "keep";
      systemd-boot.configurationLimit = 10;
      # No editing the kernel command line at the boot menu: `init=/bin/sh`
      # there is a root shell as soon as the disk is unlocked.
      systemd-boot.editor = false;
      efi.canTouchEfiVariables = true;
    };
    # Boot splash: the default bgrt theme keeps the firmware's Lenovo logo and
    # asks for the LUKS password graphically. Esc shows the boot log.
    plymouth.enable = true;
    # Sensor hub driver; this laptop reports no sensors.
    blacklistedKernelModules = [ "amd_sfh" ];
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
      "resume_offset=98657869"
      "quiet"
      # "bgrt_disable"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "iwlwifi.power_save=1"
      "iwlmvm.power_scheme=3"
      "nmi_watchdog=0"
    ];
  };

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
