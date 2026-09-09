# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  pkgs,
  inputs,
  ...
}:
let
  # Define public keys once for strict reuse across OS access and initrd decryption
  mySshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHXxFYMJ2igPzcf0Zc3w1X/C7EJ/ql8F8wu2Z/V2RwZ7 philipp@mukosey.com" # laptop
  ];
  backupreaderSshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJlSi2Gk+jQfi5oOO+/FLXPQIe2Iv65cLuQO9v1zsWoK philipp@mukosey.com"
  ];
  # mySshKeysUnlock = [
  #   "\"systemd-tty-ask-password-agent\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHXxFYMJ2igPzcf0Zc3w1X/C7EJ/ql8F8wu2Z/V2RwZ7 philipp@mukosey.com"
  # ];

in
{
  imports = [
    ./hardware-configuration.nix
    ./datasync.nix
    ./network.nix
    ../../modules/neovim.nix
    ./services.nix
    ../../modules/nixpkgs-overlay.nix

    inputs.agenix.nixosModules.default

    # Import the updated module directly from the unstable source tree
    "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/stirling-pdf.nix"
  ];

  # Ignore the built-in stable module to prevent conflicts
  disabledModules = [
    "services/web-apps/stirling-pdf.nix"
  ];

  nixpkgs = {
    overlays = [
      # FIX: Skip flaky network/timing tests for Valkey
      (final: prev: {
        valkey = prev.valkey.overrideAttrs (old: {
          doCheck = false;
        });
      })
    ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "immich-2.7.5"
    ];
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    settings = {
      auto-optimise-store = true;
      cores = 4;
      max-jobs = 1;

      # Prevent local compilation globally
      # max-jobs = 0;

      experimental-features = [
        "nix-command"
        "flakes"
      ];
      #
      #   substituters = [ "https://devenv.cachix.org" ];
      #   trusted-public-keys = [ "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=" ];
      #   trusted-users = [
      #     "root"
      #     "izvyk"
      #   ];
    };
  };

  ### GENERAL

  services.earlyoom.enable = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  ### BOOT

  systemd.settings.Manager.RuntimeWatchdogSec = "120s";

  boot = {
    resumeDevice = "/dev/mapper/cryptroot";
    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = 0;
    loader = {
      timeout = 0;
      systemd-boot.enable = true;
      systemd-boot.consoleMode = "keep";
      systemd-boot.configurationLimit = 10;
      efi.canTouchEfiVariables = true;
    };
    initrd = {
      systemd = {
        enable = true;
        network = {
          enable = true;
          networks."10-ethernet" = {
            matchConfig.Name = "en*";
            networkConfig.DHCP = "yes";
          };
        };
      };
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222; # Distinct port to avoid host key collisions with main OS SSHD
          authorizedKeys = mySshKeys;
          hostKeys = [ "/etc/nixos/initrd_ssh_host_ed25519_key" ];
        };
        # Post-login script to prompt for LUKS unlock immediately upon SSH connection
        #       postCommands = ''
        #         echo "cryptsetup-askpass; killall sshd" >> /root/.profile
        #       '';
      };
    };
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      "vm.swappiness" = 40;
    };
    kernelParams = [
      "resume_offset=533760"
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.max_pool_percent=30"
    ];
  };

  ### USERS

  users.mutableUsers = false;

  age.secrets.user-dev-password = {
    file = ../../secrets/user-dev-password.age;
    mode = "0400";
    owner = "root";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    dev = {
      isNormalUser = true;
      uid = 1001;
      shell = pkgs.fish;
      description = "Primary Administrative User";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = mySshKeys;
      hashedPasswordFile = config.age.secrets.user-dev-password.path;
      packages = [ ];
    };
    backupreader = {
      isNormalUser = true;
      uid = 1000;
      description = "Backup reader user";
      extraGroups = [ ];
      openssh.authorizedKeys.keys = backupreaderSshKeys;
      hashedPasswordFile = null;
      hashedPassword = null;
      createHome = false;
      useDefaultShell = false;
      shell = "${pkgs.util-linux}/bin/nologin";
      packages = [ ];
    };
    # backupReader = {
    #   isNormalUser = true;
    # };
  };

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    btop
    agenix
    git
    cryptsetup
    bat
    linux-firmware
    zoxide
    tmux
  ];

  ### SECURITY

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
          "-SSH_AUTH_SOCK" # doas.nix module adds this by default. We don't want user's SSH agent to leak into root's environment
          "COLORTERM"
          "TERM"
        ];
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

  # List services that you want to enable:

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
  system.stateVersion = "25.11"; # Did you read the comment?
}
