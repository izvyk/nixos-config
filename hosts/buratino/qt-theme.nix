# Qt apps in libadwaita's look: the Kvantum style with the KvLibadwaita theme.
# Kvantum reads its theme name from ~/.config/Kvantum/kvantum.kvconfig and has
# no light/dark switching of its own, so a user service rewrites that file
# whenever GNOME's dark style changes. Running Qt apps keep the theme they
# started with; the switch shows up on their next start.
#
# The window title bar is not Kvantum's: Qt's own Adwaita decoration draws it
# and already follows the dark style live.
{ pkgs, ... }:

let
  kvlibadwaita = pkgs.stdenvNoCC.mkDerivation {
    pname = "kvlibadwaita";
    version = "0-unstable-2025-09-13";
    src = pkgs.fetchFromGitHub {
      owner = "GabePoel";
      repo = "KvLibadwaita";
      rev = "1f4e0bec44b13dabfa1fe4047aa8eeaccf2f3557";
      hash = "sha256-jCXME6mpqqWd7gWReT04a//2O83VQcOaqIIXa+Frntc=";
    };
    installPhase = ''
      mkdir -p $out/share/Kvantum
      cp -a src/KvLibadwaita $out/share/Kvantum/
    '';
  };
in
{
  qt = {
    enable = true;
    style = "kvantum";
  };

  environment.systemPackages = [ kvlibadwaita ];

  systemd.user.services.kvantum-follow-dark-style = {
    description = "Switch the Kvantum theme with GNOME's dark style";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ pkgs.dconf ];
    # dconf rather than gsettings: no schema lookup, so it works before GNOME
    # has exported its environment to the user manager.
    script = ''
      key=/org/gnome/desktop/interface/color-scheme
      conf="''${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum/kvantum.kvconfig"
      apply() {
        case "$(dconf read "$key")" in
          *dark*) theme=KvLibadwaitaDark ;;
          *) theme=KvLibadwaita ;;
        esac
        mkdir -p "''${conf%/*}"
        printf '[General]\ntheme=%s\n' "$theme" > "$conf"
      }
      apply
      dconf watch "$key" | while read -r _; do apply; done
    '';
    serviceConfig.Restart = "on-failure";
  };
}
