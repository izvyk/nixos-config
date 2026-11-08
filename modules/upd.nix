# `upd`: build this host's configuration from GitHub master, show what
# changes, then ask: [s]witch now, [b]oot it next time, [r]eboot into it, or
# nothing.
#
# Only pushed commits can be deployed. The build runs as you, through nh (nom
# build log, package diff against the running system); doas is only for
# activating. nixos-rebuild activates in its own systemd unit, so a switch
# that takes down the GNOME session (and this terminal) still finishes.
{
  config,
  pkgs,
  ...
}:

let
  flake = "github:izvyk/nixos-config";
  nixos-rebuild = "${config.system.build.nixos-rebuild}/bin/nixos-rebuild";
  systemctl = "${config.systemd.package}/bin/systemctl";
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "upd";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.nh
        config.nix.package
      ];
      text = ''
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        # --refresh: fetch master now instead of reusing a cached copy.
        nh os build ${flake} -o "$tmp/result" -- --refresh
        new=$(readlink -f "$tmp/result")
        current=$(readlink -f /run/current-system)

        if [ "$(readlink -f "$new/kernel")" != "$(readlink -f /run/booted-system/kernel)" ]; then
          echo "New kernel: it takes effect after a reboot. Don't hibernate before that."
        fi
        if [ "$new" = "$current" ]; then
          echo "Already running this generation."
          exit 0
        fi
        if [ -e "$new/sw/bin/gnome-shell" ] \
          && [ "$(readlink -f "$new/sw/bin/gnome-shell")" != "$(readlink -f "$current/sw/bin/gnome-shell")" ]; then
          echo "GNOME Shell changed: a switch may end the session, boot is safer."
        fi

        read -rp "[s]witch, [b]oot, [r]eboot into it, or [N]othing? " answer
        case "$answer" in
          s) doas ${nixos-rebuild} switch --store-path "$new" ;;
          b) doas ${nixos-rebuild} boot --store-path "$new" ;;
          r) doas ${nixos-rebuild} boot --store-path "$new" && doas ${systemctl} reboot ;;
          *) echo "Nothing changed." ;;
        esac
      '';
    })
  ];
}
