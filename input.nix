{
  config,
  lib,
  pkgs,
  ...
}:

let
  sharedMain = {
    capslock = "overload(control, escape)";

    leftcontrol = "layer(alt)";
    leftalt = "layer(control)";

    rightalt = "overload(altgr, macro(leftmeta+space))";

    sysrq = "timeout(macro2(-1, 0, sysrq), 250ms, macro2(-1, 0, S-sysrq))";

    space = "overloadt(space_layer, space, 300)";

    # leftmeta = "overload(meta, macro2(-1, 0, M-o))";
    #
    # ### MOUSE
    #
    # # Thumb button
    # # "f20" = "overload(thumb_layer, layer(meta))";
    # "f20" = "overload(thumb_layer, macro2(-1, 0, M-o))";
    #
    # # Normal scroll wheel
    # "f18" = "scrollup";
    # "f19" = "scrolldown";
    #
    # # player controls on back/forward
    # "mouse1" = "timeout(macro2(-1, 0, mouse1), 400ms, macro2(-1, 0, previoussong))";
    # "mouse2" = "timeout(macro2(-1, 0, mouse2), 400ms, macro2(-1, 0, nextsong))";
    #
    # # Right mouse key as a layer trigger
    # "rightmouse" = "overload(rightmouse_layer, rightmouse)";
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

  # thumbLayerA = {
  #   # classic zoom
  #   "leftmouse" = "C-minus";
  #   "rightmouse" = "C-equal";
  #   "leftmouse+rightmouse" = "C-0";
  #
  #   # WARNING: This still works, it just doesn't need to be here!
  #   # touchpad-style zoom (e.g. in browsers)
  #   # "f18" = "scrollup";
  #   # "f19" = "scrolldown";
  #
  #   # misc
  #   "middlemouse" = "f5";
  #   # "playpause" = "nextsong";
  #
  #   # "rightmouse" = "overload(horizontalscroll_layer, C-equal)";
  #   # "leftmouse" = "overload(zoom_reset_left_layer, C-minus)";
  #   # "rightmouse" = "overload(zoom_reset_right_layer, C-equal)";
  # };
  #
  # rightmouseLayer = {
  #   # horizontal scroll for the main wheel
  #   "f18" = "scrollleft";
  #   "f19" = "scrollright";
  #
  #   # Brightness for thumb wheel
  #   "f14" = "f16";
  #   "f15" = "f17";
  #
  #   "middlemouse" = "f5";
  # };
in
{
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
          # "0000:0000"
          # "046d:c548"
          "-1050:*" # exclude Yubikeys
          "-0000:0006"
        ];
        settings = {
          main = sharedMain;
          space_layer = sharedSpaceLayer;

          # "thumb_layer:A" = thumbLayerA;
          # "rightmouse_layer" = rightmouseLayer;
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
            # "f20" = "overload(thumb_layer, macro2(-1, 0, M-o))";

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
            "leftmouse" = "macro2(250, 250, C-minus)";
            "rightmouse" = "macro2(250, 250, C-equal)";
            "leftmouse+rightmouse" = "C-0";

            # WARNING: This still works, it just doesn't need to be here!
            # touchpad-style zoom (e.g. in browsers)
            # "f18" = "scrollup";
            # "f19" = "scrolldown";

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

          # "thumb_layer:A" = thumbLayerA;
          # "rightmouse_layer" = rightmouseLayer;
        };
      };
    };
  };

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
}
