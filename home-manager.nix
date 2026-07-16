{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  # 1. We create a custom Tesseract instance with exactly the languages you need.
  # This avoids global bloat and ensures the data is present for this script.
  tesseract-ocr = pkgs.tesseract.override {
    enableLanguages = [
      "rus"
      "eng"
      "deu"
    ];
  };

  # snapshotScript = pkgs.writeShellScriptBin "agent-snapshot" ''
  #   set -euo pipefail
  #   AGENT_NAME="$1"
  #   SRC="/var/agents/$AGENT_NAME"
  #   DEST="/.snapshots/$AGENT_NAME-$(date +%Y-%m-%dT%H%M%S)"
  #
  #   # Basic input validation
  #   if [[ ! "$AGENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  #     echo "Invalid agent name" >&2
  #     exit 1
  #   fi
  #
  #   exec ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r "$SRC" "$DEST"
  # '';

in
{
  imports = [
    <home-manager/nixos>
  ];

  # 2. Tell Home Manager to use the global system packages
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.${username} =
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

      # GTK3/GTK4 cursor config for XWayland apps
      gtk = {
        enable = true;
        cursorTheme = {
          name = "Bibata-Modern-Classic";
          package = pkgs.bibata-cursors;
          size = 24;
        };
      };

      # 1. Your user-specific packages go here!
      home.packages = with pkgs; [
        # firefox
        # foot # enabled as a service
        unstable.ghostty
        unstable.kitty
        # unstable.warp-terminal
        # unstable.nushell
        # yandex-music
        # kdePackages.filelight
        baobab
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
        # unstable.opencode
        # unstable.pi-coding-agent
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
        libnotify

        unstable.swayimg
        unstable.libheif
        parallel
        unstable.imagemagickBig
        # unzip
        dotool
        tesseract-ocr
        zbar
        trash-cli
        pulseaudio

        qt6.qtwayland
        kdePackages.qttools
        fd

        chezmoi
        delta
        easyeffects

        unstable.devenv
        gocryptfs
        vaults
        obsidian
        unstable.tuxguitar
	gnome-podcasts

        # snapshotScript
      ];

      # programs.librewolf = {
      #   enable = true;
      #   # languagePacks = {
      #   policies = {
      #     # BlockAboutConfig = true;
      #     DefaultDownloadDirectory = "\${home}/Downloads";
      #     ExtensionSettings = {
      #       "uBlock0@raymondhill.net" = {
      #         default_area = "menupanel";
      #         install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      #         installation_mode = "force_installed";
      #         private_browsing = true;
      #       };
      #     };
      #   };
      #
      # };

      programs.foot = {
        enable = true;
        server.enable = true;
      };

      programs.vicinae = {
        enable = true;
        systemd = {
          enable = true;
          autoStart = true;
          target = "graphical-session.target";
        };
      };

      # This value determines the Home Manager release that your configuration is
      # compatible with. This helps avoid breakage when a new Home Manager release
      # introduces backwards incompatible changes.
      #
      # You should not change this value, even if you update Home Manager. If you do
      # want to update the value, then make sure to first check the Home Manager
      # release notes.
      home.stateVersion = "25.11"; # Please read the comment before changing.
    };
}
