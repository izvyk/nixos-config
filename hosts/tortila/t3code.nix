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
#     tailnet, docker bridges or the host itself (sandbox-net.nix).
#   - capped memory, swap, CPU and tasks; first in line for the OOM killer.
# Agents get nix (nix shell, nix-shell -p, nix develop) through the host's
# daemon. Fixed-output builds run in the host's network namespace, so they get
# the same public-internet-only rule, for every user on this host
# (sandbox-net.nix).
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
  localAddress = "10.233.0.2";

  # Without codex. The wrapper puts git and gh on t3's PATH; claude and
  # opencode come from systemPackages (on the unit's path), so `machinectl
  # shell` has them for the logins too.
  t3pkg = pkgs.unstable.t3code.override { enableCodex = false; };

  # t3 downloads a pinned Chrome for Testing headless shell into
  # ~/.t3/tools/chrome-headless-shell/linux64/<version>/ on first use (browser
  # tabs, HTML previews), with no setting to point it elsewhere. That build
  # won't start on NixOS, but nixpkgs ships the same artifact patched. Put it
  # where t3 looks, under the version this t3 pins; the build fails if a t3
  # update moves the pin out of reach of the sed.
  previewBrowser = pkgs.runCommand "t3code-preview-browser" { } ''
    version=$(sed -n 's/^const VERSION = "\([0-9.]*\)";$/\1/p' \
      $(grep -l chrome-for-testing-public ${t3pkg.unwrapped}/libexec/t3code/apps/server/dist/*.mjs))
    [ "$(wc -w <<< "$version")" = 1 ] || { echo "can't find t3's pinned Chrome version" >&2; exit 1; }
    mkdir -p $out/linux64
    ln -s ${pkgs.unstable.playwright-driver.components.chromium-headless-shell}/chrome-headless-shell-linux64 \
      $out/linux64/$version
  '';

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

  # `nixpkgs` for agents' nix shell / nix-shell -p, pinned to this flake's
  # unstable input: nothing to download or evaluate from scratch.
  nixPath = [ "nixpkgs=${inputs.nixpkgs-unstable}" ];
in
{
  containers.t3code = {
    autoStart = true;
    privateUsers = "pick";
    privateNetwork = true;
    hostAddress = "10.233.0.1";
    inherit localAddress;

    config = {
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
        # Only the host can reach the container anyway (forward chain below).
        firewall.enable = false;
      };

      # What agents and `machinectl shell` sessions get, on top of NixOS's
      # base set (bash, coreutils, curl, grep, sed, tar, ssh, …); agents also
      # get git and gh from t3's wrapper. Everything else comes from nix.
      environment.systemPackages = [
        t3pkg
        pkgs.unstable.claude-code
        # The way to Muse Spark and other non-Anthropic models: nixpkgs builds
        # it from source, while t3's dedicated Muse Code provider wants Meta's
        # closed, self-updating CLI.
        pkgs.unstable.opencode
        pkgs.jq
        pkgs.unzip
        pkgs.nodejs
        pkgs.python3
      ];
      environment.variables.OPENCODE_CONFIG = "${opencodeConfig}";

      # For pages rendered by the headless browser.
      fonts.packages = with pkgs; [
        dejavu_fonts
        liberation_ttf
        noto-fonts-color-emoji
      ];

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
        path = [ "/run/current-system/sw" ];
        environment = {
          T3CODE_TELEMETRY_ENABLED = "false";
          # Login shells get these from the system config; services don't.
          NIX_PATH = lib.concatStringsSep ":" nixPath;
          OPENCODE_CONFIG = "${opencodeConfig}";
        };
        preStart = ''
          mkdir -p ~/.t3/tools ~/.claude
          ln -sfnT ${previewBrowser} ~/.t3/tools/chrome-headless-shell
          ln -sfnT ${agentNotes} ~/.claude/CLAUDE.md
        '';
        # No XDG_RUNTIME_DIR here, so t3 skips its per-agent systemd --user
        # scopes and agents stay in this unit's cgroup: the container's limits
        # apply and a stop kills them all.
        serviceConfig = {
          ExecStart = "${lib.getExe' t3pkg "t3"} serve --host ${localAddress} --port 3773";
          User = "t3code";
          Group = "t3code";
          WorkingDirectory = "/var/lib/t3code";
          Restart = "on-failure";
          RestartSec = 5;
          LimitNOFILE = 65536;

          # Second layer: no setuid helpers, nothing writable outside home and
          # /tmp, no /dev/net/tun (which the container has), no kernel log
          # reading, and less kernel surface for an exploit to start from.
          # Chrome's sandbox needs user/pid/net namespaces and chroot; the
          # JITs rule out MemoryDenyWriteExecute. Options the container
          # already guarantees (kernel tunables, modules, clock, …) are left
          # out.
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ "/var/lib/t3code" ];
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelLogs = true;
          LockPersonality = true;
          RestrictNamespaces = "user pid net";
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "chroot"
          ];
          # Fail odd syscalls of arbitrary dev tooling instead of killing it.
          SystemCallErrorNumber = "EPERM";
        };
      };
    };
  };

  # Agents are the most expendable thing on this box. MemoryMax doesn't cover
  # swap. No IOWeight: only BFQ or io.cost honour it, and tortila has neither.
  systemd.services."container@t3code".serviceConfig = {
    MemoryHigh = "50%";
    MemoryMax = "60%";
    MemorySwapMax = "4G";
    CPUWeight = 50;
    TasksMax = 4096;
    OOMScoreAdjust = 500;
  };

  sandbox.interfaces = [ "ve-t3code" ];
}
