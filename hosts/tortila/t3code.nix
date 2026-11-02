{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
# T3 Code (https://github.com/pingdotgg/t3code) driving Claude Code and
# OpenCode, in its own NixOS container. New threads default to "Full access"
# (no approval prompts), so the OS is the boundary, not the app:
#   - own root FS: only /nix/store is shared (read-only). No /home, /var/lib,
#     /run/agenix, docker or postgres sockets.
#   - own user namespace (privateUsers): container root is not host root.
#   - own network namespace: the loopback-only services on this host
#     (AnkiConnect, n8n, ollama, docker-published ports, …) don't exist in
#     there. Egress is NATed and may reach the public internet only — no LAN,
#     tailnet, docker bridges or the host itself (see t3code-isolation below).
#   - capped memory/CPU/IO, and first in line for the OOM killer.
# Agents get nix (nix shell, nix-shell -p, nix develop) through the host's
# daemon. Fixed-output builds run in the host's network namespace, so they get
# the same public-internet-only rule, for every user on this host.
# Everything comes from nixpkgs, no nix-ld: t3code, claude-code, opencode, and
# the headless Chrome t3 would otherwise download at runtime.
#
# Ingress: tailscale-serve-l7 (network.nix) proxies svc:t3code to the
# container's veth address. Clients still need a one-time pairing token.
#
# One-time setup, as root on tortila:
#   machinectl shell t3code@t3code    # login shell as the agent user, then:
#     claude auth login
#     opencode auth login haimaker    # API key from app.haimaker.ai
#     t3 auth pairing create --base-url https://t3code.<tailnet>
let
  hostAddress = "10.233.0.1";
  localAddress = "10.233.0.2";
  port = 3773;
  nixbld = toString config.ids.gids.nixbld;

  # Puts claude and opencode (plus git and gh, on by default) on t3's PATH.
  # OpenCode is the way to Muse Spark and other non-Anthropic models: nixpkgs
  # builds it from source, while t3's dedicated Muse Code provider wants
  # Meta's closed, self-updating CLI.
  t3pkg = pkgs.unstable.t3code.override {
    enableClaude = true;
    enableOpencode = true;
    enableCodex = false;
  };

  # Haimaker isn't in OpenCode's built-in catalog (models.dev), so declare it
  # as an OpenAI-compatible provider. Passed via OPENCODE_CONFIG, which
  # OpenCode layers over ~/.config/opencode/opencode.json, so that one stays
  # editable. The key lives in OpenCode's auth store, not here.
  opencodeConfig = (pkgs.formats.json { }).generate "opencode.json" {
    "$schema" = "https://opencode.ai/config.json";
    provider.haimaker = {
      npm = "@ai-sdk/openai-compatible";
      name = "Haimaker";
      options.baseURL = "https://api.haimaker.ai/v1";
      models."meta/muse-spark-1.3-contributor" = {
        name = "Muse Spark 1.3 (contributor)";
        limit = {
          context = 1048576;
          output = 131072;
        };
      };
    };
  };

  # t3 runs a pinned Chrome for Testing headless shell for browser tabs and
  # HTML previews, downloaded into ~/.t3/tools on first use. That build
  # expects an FHS system and won't start here, but nixpkgs ships the same
  # artifact autoPatchelf'd. Link it in under the version this t3 pins, so t3
  # finds it already installed. Fails the build if a t3 update moves the pin
  # out of reach of the sed — better than a silent download at runtime.
  previewBrowser = pkgs.runCommand "t3code-preview-browser" { } ''
    version=$(sed -n 's/^const VERSION = "\([0-9.]*\)";$/\1/p' \
      $(grep -l chrome-for-testing-public ${t3pkg.unwrapped}/libexec/t3code/apps/server/dist/*.mjs))
    if [ "$(wc -w <<< "$version")" != 1 ]; then
      echo "t3code: can't find the pinned chrome-headless-shell version" >&2
      exit 1
    fi
    mkdir -p $out/linux64
    ln -s ${pkgs.unstable.playwright-driver.components.chromium-headless-shell}/chrome-headless-shell-linux64 \
      $out/linux64/$version
  '';

  # `nixpkgs` for agents' nix shell / nix-shell -p: pinned to this flake's
  # unstable input, so nothing is downloaded or evaluated from scratch.
  nixPath = [ "nixpkgs=${inputs.nixpkgs-unstable}" ];

  # PATH for agents, on top of t3's (claude, opencode, git, gh) and
  # claude-code's own (rg, ps). Everything else comes from nix.
  agentTools = with pkgs; [
    config.nix.package
    bashInteractive
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    diffutils
    patch
    gnutar
    gzip
    xz
    unzip
    which
    file
    less
    curl
    jq
    fd
    openssh
    nodejs
    python3
  ];

  # User-level rules, so agents reach for nix instead of apt. Claude reads
  # ~/.claude/CLAUDE.md; OpenCode falls back to it while it has no AGENTS.md
  # of its own. Only what agents need for their work: nothing about what's
  # around the container.
  agentNotes = pkgs.writeText "t3code-agent-notes.md" ''
    # Environment
    - This is NixOS: no apt, no sudo, no FHS. Binaries that npm/pip/curl
      download and that expect /lib64/ld-linux-*.so won't run; use the
      nixpkgs package instead.
    - Missing tool: `nix shell nixpkgs#<pkg> -c <cmd>` or
      `nix-shell -p <pkg> --run '<cmd>'`. `nixpkgs` is pinned locally.
    - Project with a flake.nix: `nix develop -c <cmd>`; with a shell.nix:
      `nix-shell --run '<cmd>'`.
    - Only the public internet is reachable from here.
  '';
in
{
  containers.t3code = {
    autoStart = true;
    privateUsers = "pick";
    privateNetwork = true;
    inherit hostAddress localAddress;

    config = {
      # Reuse the host's package set (unstable overlay, allowUnfree).
      nixpkgs.pkgs = pkgs;
      system.stateVersion = "26.05";

      # Client side only: the host's daemon does the building.
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          # Only the pinned registry below; otherwise every flake command
          # first downloads the global one from channels.nixos.org.
          flake-registry = "";
        };
        registry.nixpkgs.flake = inputs.nixpkgs-unstable;
        inherit nixPath;
      };

      networking = {
        # The host's resolv.conf points at resolved's 127.0.0.53 stub, which
        # doesn't exist in this network namespace, and the router's DNS is on
        # the blocked LAN.
        useHostResolvConf = false;
        nameservers = [
          "9.9.9.9"
          "1.1.1.1"
        ];
        nftables.enable = true;
        firewall.allowedTCPPorts = [ port ];
      };

      # For pages rendered by the headless browser.
      fonts.packages = with pkgs; [
        dejavu_fonts
        liberation_ttf
        noto-fonts-color-emoji
      ];

      # For `machinectl shell` sessions (claude/opencode auth login, t3 auth …).
      environment.systemPackages = [
        t3pkg
        pkgs.unstable.claude-code
        pkgs.unstable.opencode
      ]
      ++ agentTools;
      environment.variables.OPENCODE_CONFIG = "${opencodeConfig}";

      users.users.t3code = {
        isSystemUser = true;
        group = "t3code";
        home = "/var/lib/t3code";
        createHome = true;
        # Login shell for machinectl, and what t3's terminals spawn.
        shell = pkgs.bashInteractive;
      };
      users.groups.t3code = { };

      systemd.services.t3code = {
        description = "T3 Code server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = agentTools;

        environment = {
          T3CODE_TELEMETRY_ENABLED = "false";
          # Services don't get the login environment that sets these.
          NIX_PATH = lib.concatStringsSep ":" nixPath;
          OPENCODE_CONFIG = "${opencodeConfig}";
        };

        preStart = ''
          mkdir -p "$HOME/.t3/tools" "$HOME/.claude"
          ln -sfnT ${previewBrowser} "$HOME/.t3/tools/chrome-headless-shell"
          ln -sfnT ${agentNotes} "$HOME/.claude/CLAUDE.md"
        '';

        serviceConfig = {
          # The veth address is where tailscaled on the host reaches it. No
          # XDG_RUNTIME_DIR here, so t3 skips its per-agent systemd --user
          # scopes and agents stay in this unit's cgroup: the container's
          # limits apply and a stop kills them all.
          ExecStart = "${lib.getExe' t3pkg "t3"} serve --host ${localAddress} --port ${toString port}";
          User = "t3code";
          Group = "t3code";
          StateDirectory = [
            "t3code"
            "t3code/projects"
          ];
          StateDirectoryMode = "0700";
          WorkingDirectory = "/var/lib/t3code/projects";
          Restart = "on-failure";
          RestartSec = 5;
          LimitNOFILE = 65536;

          # Second layer, inside the container. Not set on purpose:
          # RestrictNamespaces and SystemCallFilter (Chrome's sandbox,
          # bubblewrap and debuggers need namespaces, chroot, mount and
          # ptrace; the container is the boundary), MemoryDenyWriteExecute
          # (node's and bun's JITs).
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectProc = "invisible";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };
    };
  };

  # Agents are the most expendable thing on this box.
  systemd.services."container@t3code".serviceConfig = {
    MemoryHigh = "50%";
    MemoryMax = "60%";
    CPUWeight = 50;
    IOWeight = 50;
    TasksMax = 4096;
    OOMScoreAdjust = 500;
  };

  # Masquerade container traffic out of whichever uplink is active (eno1 or
  # wlan0, hence no externalInterface).
  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-t3code" ];
  };

  # Separate table with accept policies: it only ever narrows what the
  # container and nix builds may do, and leaves the exit-node forwarding alone.
  networking.nftables.tables.t3code-isolation = {
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

      # Unspecified/loopback, ULA (LAN and tailnet), link-local, multicast.
      set blocked6 {
        type ipv6_addr
        flags interval
        elements = { ::/127, fc00::/7, fe80::/10, ff00::/8 }
      }

      chain input {
        type filter hook input priority filter; policy accept;
        iifname "ve-t3code" ct state established,related accept
        iifname "ve-t3code" counter reject with icmpx admin-prohibited comment "container -> host"
      }

      chain forward {
        type filter hook forward priority filter; policy accept;
        oifname "ve-t3code" ct state established,related accept
        oifname "ve-t3code" counter drop comment "-> container; only the host itself may connect"
        iifname "ve-t3code" meta nfproto != ipv4 counter drop comment "container has no IPv6"
        iifname "ve-t3code" ip daddr @blocked4 counter reject with icmpx admin-prohibited comment "container -> private ranges"
      }

      # Fixed-output builds (fetchers) run as nix's build users in the host's
      # network namespace, whoever asked the daemon for them — an agent could
      # otherwise read host-local services through a build log. Same rule as
      # for the container, plus the resolved stub that the build sandbox's
      # resolv.conf points at. Every rule matches the group positively: the
      # kernel's own packets (RSTs, ICMP errors, echo replies, NDP) have no
      # owner, so `skgid != … accept` would let them fall through to the
      # rejects and break the host's networking.
      chain output {
        type filter hook output priority filter; policy accept;
        meta skgid ${nixbld} ip daddr 127.0.0.53 meta l4proto { tcp, udp } th dport 53 accept comment "resolved stub"
        meta skgid ${nixbld} ip daddr @blocked4 counter reject with icmpx admin-prohibited comment "nix build -> private ranges"
        meta skgid ${nixbld} ip6 daddr @blocked6 counter reject with icmpx admin-prohibited comment "nix build -> private ranges"
      }
    '';
  };

  assertions = [
    {
      # Builds would then run under per-build uids/gids instead of nixbld.
      assertion = !(config.nix.settings.auto-allocate-uids or false);
      message = "t3code.nix: the nix build egress rule matches the nixbld group, which auto-allocate-uids builds don't run as.";
    }
  ];
}
