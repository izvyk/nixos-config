{
  config,
  lib,
  pkgs,
  ...
}:

let
  # 2. We define the script as a package.
  # "writeShellApplication" is superior to "writeShellScriptBin" because
  # it runs ShellCheck on build and handles PATH automatically.
  # ocr-script = pkgs.writeShellApplication {
  #   name = "ocr-selection";
  #   runtimeInputs = [
  #     pkgs.grim
  #     pkgs.slurp
  #     pkgs.imagemagick
  #     pkgs.wl-clipboard
  #     tesseract-ocr
  #   ];
  #   text = ''
  #     # The pipeline: Select -> Process -> OCR -> Clipboard
  #     grim -g "$(slurp)" - | \
  #       magick - -auto-level -normalize -enhance -sharpen 0x1 -resize 200% - | \
  #       tesseract - - -l rus+eng+deu quiet | \
  #       wl-copy
  #   '';
  # };
in
{
  imports = [
    # "${unstable-src}/nixos/modules/programs/wayland/dms-shell.nix"
    # "${unstable-src}/nixos/modules/programs/wayland/niri.nix"
  ];
  disabledModules = [
    # "programs/wayland/niri.nix"
  ];
  home-manager.users.izvyk =
    { pkgs, ... }:
    {

      home.packages = with pkgs; [
        waybar
        kdePackages.kdeconnect-kde
        awww
        killall
        cliphist
        wl-gammarelay-rs
        rofi
        python3Minimal
        jq
        pulseaudio
        grim
        ocr-script
        hypridle
        # unstable.noctalia-shell
        # unstable.quickshell # The underlying framework Noctalia runs on
        # unstable.brightnessctl
        # unstable.cliphist
        # unstable.wlsunset
        # (pkgs.writeShellApplication {
        #   name = "niri-smooth-sleep";
        #   runtimeInputs = [
        #     pkgs.brillo
        #     pkgs.niri
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
        #     niri msg action power-off-monitors
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
      systemd.user.services.hypridle = {
        Unit = {
          Description = "Hypridle (Bound strictly to Niri)";
          BindsTo = [ "niri.service" ];
          After = [ "niri.service" ];
        };
        Service = {
          # You MUST keep this block so systemd knows what to run
          ExecStart = "${pkgs.hypridle}/bin/hypridle";
          Restart = "on-failure";
        };
        Install = {
          WantedBy = [ "niri.service" ];
        };
      };

      systemd.user.targets.session-lock = {
        Unit.Description = "Tracks whether the session is locked";
      };

      systemd.user.services.screen-dim = {
        Unit.Description = "Smoothly dim and power off the display(s)";
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.writeShellScript "screen-dim-start" ''
            ${pkgs.brillo}/bin/brillo -O
            ${pkgs.brillo}/bin/brillo -q -u 200000 -S 0
            ${pkgs.niri}/bin/niri msg action power-off-monitors
          ''}";
          ExecStop = "${pkgs.writeShellScript "screen-dim-stop" ''
            ${pkgs.niri}/bin/niri msg action power-on-monitors
            ${pkgs.brillo}/bin/brillo -q -u 500000 -I
          ''}";
        };
      };
      # programs.dms-shell = {
      #   enable = true;
      #
      #   # Notice we use `pkgs.unstable` here because of your packageOverrides
      #   package = pkgs.unstable.dms;
      #   quickshell.package = pkgs.unstable.quickshell;
      # };
    };

  programs.niri = {
    enable = true;
    package = pkgs.unstable.niri;
  };
  # programs.hyprlock.enable = true;
  # services.hypridle.enable = false;
  programs.kdeconnect = {
    enable = true;
  };
}
