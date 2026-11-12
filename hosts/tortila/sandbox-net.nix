{ config, lib, ... }:
# Network rules for everything untrusted on this host: the t3code container
# (t3code.nix), the mini-lab VM (minilab.nix) and nix's fixed-output builds.
# Each sandbox adds its host-side interface to `sandbox.interfaces`; it then
# gets NATed egress to the public internet only — no LAN, tailnet, docker
# bridges, other sandboxes or the host itself. The host may still connect in.
let
  ifaces = "{ ${lib.concatMapStringsSep ", " (i: ''"${i}"'') config.sandbox.interfaces} }";
  nixbld = toString config.ids.gids.nixbld;
in
{
  options.sandbox.interfaces = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Host-side interfaces of untrusted containers and VMs.";
  };

  config = {
    # Masquerade sandbox traffic out of whichever uplink is active (eno1 or
    # wlan0, hence no externalInterface).
    networking.nat = {
      enable = true;
      internalInterfaces = config.sandbox.interfaces;
    };

    # Separate table with accept policies: it only ever narrows what the
    # sandboxes and nix builds may do, and leaves the exit-node forwarding
    # alone.
    networking.nftables.tables.sandbox-isolation = {
      family = "inet";
      content = ''
        # RFC 1918 (LAN, docker bridges), CGNAT (tailnet, MagicDNS), loopback,
        # link-local, "this network", IETF protocol assignments, benchmarking,
        # multicast and reserved.
        set blocked4 {
          type ipv4_addr
          flags interval
          elements = {
            0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16,
            172.16.0.0/12, 192.0.0.0/24, 192.168.0.0/16, 198.18.0.0/15, 224.0.0.0/3
          }
        }

        chain input {
          type filter hook input priority filter; policy accept;
          iifname ${ifaces} ct state established,related accept
          iifname ${ifaces} counter reject with icmpx admin-prohibited comment "sandbox -> host"
        }

        # No sandbox gets an IPv6 address or route, but root inside one can
        # still hand IPv6 packets to the host (its MAC is known from ARP), and
        # this host forwards IPv6 as an exit node: a global LAN prefix can't
        # be listed statically, so no IPv6 at all.
        chain forward {
          type filter hook forward priority filter; policy accept;
          oifname ${ifaces} ct state established,related accept
          oifname ${ifaces} counter drop comment "-> sandbox; only the host itself may connect"
          iifname ${ifaces} meta nfproto ipv6 counter reject with icmpx admin-prohibited comment "sandbox -> IPv6"
          iifname ${ifaces} ip daddr @blocked4 counter reject with icmpx admin-prohibited comment "sandbox -> private ranges"
        }

        # Fixed-output builds (fetchers) run as nix's build users (group
        # nixbld; not with auto-allocate-uids) in the host's network namespace,
        # whoever asked the daemon for them — an agent could otherwise read
        # host-local services through a build log. Same rule as for the
        # sandboxes, plus the resolved stub the build sandbox's resolv.conf
        # points at, and no IPv6 for the same reason. Every rule matches the
        # group positively: the kernel's own packets (RSTs, ICMP errors, echo
        # replies, NDP) have no owner, so `skgid != … accept` would let them
        # fall through to the rejects and break the host's networking.
        chain output {
          type filter hook output priority filter; policy accept;
          meta skgid ${nixbld} ip daddr 127.0.0.53 meta l4proto { tcp, udp } th dport 53 accept comment "resolved stub"
          meta skgid ${nixbld} ip daddr @blocked4 counter reject with icmpx admin-prohibited comment "nix build -> private ranges"
          meta skgid ${nixbld} meta nfproto ipv6 counter reject with icmpx admin-prohibited comment "nix build -> IPv6"
        }
      '';
    };
  };
}
