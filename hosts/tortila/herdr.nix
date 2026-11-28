{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
# herdr-core (https://github.com/herdrdev/herdr-core), the server behind the
# Herdr desktop and phone apps: it runs the agents' terminals, the apps attach
# to it. A second agent box next to T3 Code's, with the same boundary (see
# t3code.nix): own root FS, own agent logins, own limits. The two share only
# the host's nix daemon and store, so what one box builds the other can read.
#
# Unlike t3 there is no port to proxy. Core listens on a Unix socket only;
# a client runs `ssh <machine> hc connect` and speaks the protocol over stdin
# and stdout. So the way in is an sshd inside the container, proxied from the
# tailnet as svc:herdr (network.nix), for the keys of dev on this host and
# the Herdr phone app's.
#
# Core starts with the first `hc` call and stays: the user lingers, so its
# runtime dir (core's socket) and the terminals outlive the SSH session. A
# container restart ends them.
#
# Agents run in that user's session, not in a hardened unit like t3code's. So
# the whole container runs with no-new-privileges: setuid bits and file
# capabilities do nothing in it, which leaves no setuid-root binary as a way
# to root in the box. No syscall filter, though.
#
# One-time setup, from buratino:
#   ssh herdr@herdr.<tailnet>         # also accepts the host key, which the
#                                     # app can't do on its own
#     claude auth login
#     opencode auth login haimaker    # API key from app.haimaker.ai
#   Herdr app: Settings → Machines → herdr@herdr.<tailnet>
let
  localAddress = "10.233.2.2";
  user = "herdr";

  box = import ./agent-box.nix { inherit inputs pkgs; };
in
{
  containers.herdr = {
    autoStart = true;
    privateUsers = "pick";
    privateNetwork = true;
    hostAddress = "10.233.2.1";
    inherit localAddress;
    extraFlags = [ "--no-new-privileges=yes" ];

    config = {
      imports = [ box.guest ];

      system.stateVersion = "26.05";

      environment.systemPackages = [
        # The same build as buratino's (shared flake.lock), so the app finds a
        # core it can use and has nothing to copy over. `hc update` can't
        # replace a store path; update through nixpkgs.
        pkgs.unstable.herdr-core
        pkgs.git
        pkgs.gh
      ];

      services.openssh = {
        enable = true;
        # Only the keys below: an agent can't add one of its own.
        authorizedKeysInHomedir = false;
        # ed25519 only; NixOS would also generate an RSA host key.
        hostKeys = [
          {
            type = "ed25519";
            path = "/etc/ssh/ssh_host_ed25519_key";
          }
        ];
        settings = {
          AllowUsers = [ user ];
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          # Agents are this very user: never hand them a client's ssh-agent.
          AllowAgentForwarding = false;
        };
      };

      users.users.${user} = {
        isNormalUser = true;
        # Bash, the default: what core's terminals spawn, and a login that
        # prints nothing, which `hc connect` needs.
        openssh.authorizedKeys.keys = config.users.users.dev.openssh.authorizedKeys.keys ++ [
          # Herdr app on the phone (Google Play dev.herdr.app); generated
          # there, the private half stays in the phone's keystore.
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZIbHx3J8vbKpCQgA0VIAQR8UJ2kgqnT9Dsj2265oVt herdr-mobile"
        ];
        linger = true;
      };

      systemd.tmpfiles.rules = [
        "d /home/${user}/.claude 0755 ${user} users -"
        "L+ /home/${user}/.claude/CLAUDE.md - - - - ${box.notes}"
      ];
    };
  };

  systemd.services."container@herdr" = {
    serviceConfig = box.limits;
    preStart = lib.mkAfter box.rootGuard;
  };

  sandbox.interfaces = [ "ve-herdr" ];
}
