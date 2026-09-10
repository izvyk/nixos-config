{
  lib,
  pkgs,
  ...
}:

let
  tapHold =
    {
      key,
      timeout ? 250,
      heldAction,
    }:
    {
      "${key}" = "timeout(macro2(-1, 0, ${key}), ${toString timeout}ms, macro2(-1, 0, ${heldAction}))";
    };

  F21Lock =
    key:
    tapHold {
      key = key;
      timeout = 400;
      heldAction = "f21";
    }; # BUG: fires on release instead of firing on timeout expiration if the mouse pointer is moving

  sharedMain = {
    capslock = "overload(control, escape)";

    leftcontrol = "layer(alt)";
    leftalt = "layer(control)";

    rightalt = "overload(altgr, macro(leftmeta+space))";

    space = "overloadt(space_layer, space, 300)";

    # a = "timeout(w, 250ms, macro2(-1, 0, q))";
    # a = "timeout(macro2(0, 0, w), 250ms, macro2(0, 0, q))"; # BUG: q is typed exactly twice
  }
  // tapHold {
    key = "sysrq";
    heldAction = "S-sysrq";
  }
  // F21Lock "escape";

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

  sharedCtrlShiftLayer = {
    "[" = "C-pageup";
    "]" = "C-pagedown";
  };

  numberRowToF = [
    {
      key = "1";
      f = "f1";
    }
    {
      key = "2";
      f = "f2";
    }
    {
      key = "3";
      f = "f3";
    }
    {
      key = "4";
      f = "f4";
    }
    {
      key = "5";
      f = "f5";
    }
    {
      key = "6";
      f = "f6";
    }
    {
      key = "7";
      f = "f7";
    }
    {
      key = "8";
      f = "f8";
    }
    {
      key = "9";
      f = "f9";
    }
    {
      key = "0";
      f = "f10";
    }
    {
      key = "minus";
      f = "f11";
    }
    {
      key = "equal";
      f = "f12";
    }
  ];

  fKeyBindings = lib.mergeAttrsList (
    map (
      p:
      tapHold {
        key = p.key;
        heldAction = p.f;
      }
    ) numberRowToF
  );
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
          "control+shift" = sharedCtrlShiftLayer;
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

            # Right mouse key as a layer trigger
            "rightmouse" = "overload(rightmouse_layer, rightmouse)";
          }
          # player controls on back/forward
          // tapHold {
            key = "mouse1";
            timeout = 400;
            heldAction = "previoussong";
          }
          // tapHold {
            key = "mouse2";
            timeout = 400;
            heldAction = "nextsong";
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
          main =
            sharedMain
            # // tapHold {
            #   key = "home";
            #   heldAction = "f24";
            # }
            // F21Lock "grave"
            // fKeyBindings;

          # Fix input lag on M-grave
          meta.grave = "M-grave";

          # Fix input lag on C-grave
          control.grave = "C-grave";

          # Fix ~ repeat on S-grave
          shift.grave = "S-grave";

          "control+shift" = sharedCtrlShiftLayer;

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

  i18n.inputMethod.enable = false;
}
