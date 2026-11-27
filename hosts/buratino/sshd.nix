{
  username,
  ...
}:
# SSH into buratino, for herdr-mobile (Android) while away from home.
#
# Reachable from the tailnet only: the firewall opens 22 on tailscale0 and
# nowhere else (no LAN, no public Wi-Fi). Only the keys listed here get in,
# and only as ${username}.
#
# herdr-mobile (github.com/tuan3w/herdr-mobile) runs fixed scripts through
# exec channels (`sh -c …` → `herdr remote-api-bridge`) and needs no
# forwarding of any kind; the agents' terminals are herdr's own PTYs. Its
# only optional forwarding is direct-tcpip for previewing a localhost web
# page, which stays off.
#
# Tighten further in the Tailscale admin console: an ACL/grant that lets
# only the phone reach buratino:22.
let
  # Generated on the phone (herdr-mobile → Generate key, Ed25519). The
  # private half never leaves the phone's keystore.
  phoneSshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmCHYa2CgANu9HOxTFnxy5ra1wBXXYg7+TZ+byGMVfE herdr-mobile"
  ];
in
{
  services.openssh = {
    enable = true;
    # Not on every interface: only tailscale0, below.
    openFirewall = false;
    # Only the keys from this file. With the default, anything running as
    # ${username} (a compromised npm package, say) could append its own key
    # to ~/.ssh/authorized_keys and get a way in from the tailnet that
    # outlives it.
    authorizedKeysInHomedir = false;
    # ed25519 only; NixOS would also generate an RSA host key.
    hostKeys = [
      {
        type = "ed25519";
        path = "/etc/ssh/ssh_host_ed25519_key";
      }
    ];
    settings = {
      AllowUsers = [ username ];
      PermitRootLogin = "no";
      AuthenticationMethods = "publickey";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      AllowStreamLocalForwarding = false;
      PermitTunnel = false;
      MaxAuthTries = 3;
      LoginGraceTime = 20;
    };
  };

  # `restrict` turns off every kind of forwarding and the PTY for these keys
  # (on top of the global settings above). `pty` comes back so a plain SSH
  # client (Termux) still works as a fallback; herdr-mobile itself doesn't
  # need it.
  users.users.${username}.openssh.authorizedKeys.keys = map (k: "restrict,pty ${k}") phoneSshKeys;

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];
}
