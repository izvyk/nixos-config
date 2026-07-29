{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
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
      pkgs.tesseract5
    ];
    text = ''
      # The pipeline: Select -> Process -> OCR -> Clipboard
      grim -g "$(slurp)" - | \
        magick - -auto-level -normalize -enhance -sharpen 0x1 -resize 200% - | \
        tesseract - - -l eng+deu+rus quiet | \
        wl-copy
    '';
  };
in
{
  imports = [
    # "${unstable-src}/nixos/modules/programs/wayland/dms-shell.nix"
    # "${unstable-src}/nixos/modules/programs/wayland/hyprland.nix"
  ];
  disabledModules = [
    # "programs/wayland/hyprland.nix"
  ];
  home-manager.users.${username} =
    { pkgs, ... }:
    {

      services.awww.enable = true;
      services.playerctld.enable = true;
      services.udiskie.enable = true;
      # services.hypridle.enable = true;
      # services.hyprpolkitagent.enable = true;

      services.kdeconnect = {
        enable = true;
        indicator = true;
      };

      programs.waybar = {
        enable = true;
        systemd.enable = true;
      };
      home.packages = with pkgs; [
        killall
        cliphist
        wl-gammarelay-rs
        python3Minimal
        jq
        pulseaudio
        grim
        ocr-script
        # unstable.noctalia-shell
        # unstable.quickshell # The underlying framework Noctalia runs on
        # unstable.brightnessctl
        # unstable.cliphist
        # unstable.wlsunset
        # (pkgs.writeShellApplication {
        #   name = "hyprland-smooth-sleep";
        #   runtimeInputs = [
        #     pkgs.brillo
        #     pkgs.hyprland
        #     pkgs.coreutils
        #   ];
        #   text = ''
        #     # 1. Save the current brightness
        #     brillo -O
        #
        #     # 2. Dim to 0 smoothly over 200ms
        #     brillo -q -u 200000 -S 0
        #
        #     # 3. Tell Niri to power off monitors
        #     hyprland msg action power-off-monitors
        #
        #     # 4. Wait half a second for the hardware panel to actually power down
        #     # Adjust this up to 1.0 if you see a bright flash before the screen goes black
        #     sleep 1.5
        #
        #     # 5. Restore brightness silently in the background
        #     brillo -I
        #   '';
        # })
      ];
      # systemd.user.services.hypridle = {
      #   Unit = {
      #     Description = "Hypridle (Bound strictly to Hyprland)";
      #     BindsTo = [ "hyprland.service" ];
      #     After = [ "hyprland.service" ];
      #   };
      #   Service = {
      #     ExecStart = "${pkgs.hypridle}/bin/hypridle";
      #     Restart = "on-failure";
      #   };
      #   Install = {
      #     WantedBy = [ "hyprland.service" ];
      #   };
      # };

      # systemd.user.targets.session-lock = {
      #   Unit.Description = "Tracks whether the session is locked";
      # };
      #
      # systemd.user.services.screen-dim = {
      #   Unit.Description = "Smoothly dim and power off the display(s)";
      #   Service = {
      #     Type = "oneshot";
      #     RemainAfterExit = true;
      #     ExecStart = "${pkgs.writeShellScript "screen-dim-start" ''
      #       ${pkgs.brillo}/bin/brillo -O
      #       ${pkgs.brillo}/bin/brillo -q -u 200000 -S 0
      #       # ${pkgs.hyprland}/bin/hyprland msg action power-off-monitors
      #     ''}";
      #     ExecStop = "${pkgs.writeShellScript "screen-dim-stop" ''
      #       # ${pkgs.hyprland}/bin/hyprland msg action power-on-monitors
      #       ${pkgs.brillo}/bin/brillo -q -u 500000 -I
      #     ''}";
      #   };
      # };
      # programs.dms-shell = {
      #   enable = true;
      #
      #   # Notice we use `pkgs.unstable` here because of your packageOverrides
      #   package = pkgs.unstable.dms;
      #   quickshell.package = pkgs.unstable.quickshell;
      # };
    };

  programs.hyprland = {
    enable = true;
    package = pkgs.unstable.hyprland;

    withUWSM = true;
  };
  programs.hyprlock.enable = true;
}
