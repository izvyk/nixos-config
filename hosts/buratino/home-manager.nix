{
  config,
  lib,
  pkgs,
  username,
  inputs,
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
    inputs.home-manager.nixosModules.home-manager
  ];

  # System-wide, not per-user: Quick Unlock authenticates through polkit,
  # which reads action files only from the system profile.
  environment.systemPackages = [ pkgs.keepassxc ];

  # 2. Tell Home Manager to use the global system packages
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  # The activation at boot (0.8 s) held back the login screen, which only
  # needs it done before the user logs in. Logins start the user's systemd
  # instance, so it waits there instead.
  systemd.services."home-manager-${username}".before = lib.mkForce [
    "user@${toString config.users.users.${username}.uid}.service"
  ];

  home-manager.users.${username} =
    { pkgs, ... }:
    {
      # home.stateVersion = "25.11";

      home.pointerCursor = {
        enable = true;
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
        unstable.ghostty
        # unstable.kitty
        # unstable.warp-terminal
        # unstable.nushell
        # yandex-music
        # kdePackages.filelight
        # Temporary until brave-origin is fixed
        brave-origin
        baobab
        # materialgram
        # telegram-desktop
        mpv
        # vscode
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
        unstable.claude-code
        unstable.claude-agent-acp
        # Shell history + agent threads, synced to tortila (svc:atuin).
        # Unstable for Threads (>= 18.24). Config is in chezmoi.
        unstable.atuin
        bubblewrap
        # Desktop client for tortila's T3 Code (Connections → Add environment).
        # Unwrapped: the wrapper only adds agent CLIs (codex, gh, git) for a
        # local backend, and agents don't run here.
        unstable.t3code.unwrapped
        # Config, roles and the fish key binding are in chezmoi.
        aichat
        poppler-utils # pdftotext, for `aichat -f file.pdf`
        # unstable.opencode
        # unstable.pi-coding-agent
        # unstable.antigravity-ide
        lazygit
        unstable.yazi
        # gnumake
        # gcc
        # glibc.static
        # chromium
        # libreoffice
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
        ddcutil

        qt6.qtwayland
        kdePackages.qttools
        fd

        chezmoi
        delta
        easyeffects

        unstable.devenv
        gocryptfs
        obsidian
        unstable.tuxguitar
        gnome-podcasts
        unstable.cassette

        # snapshotScript
      ];

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
