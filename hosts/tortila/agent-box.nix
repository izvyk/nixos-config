{ inputs, pkgs }:
# What the agent containers on this host (t3code.nix, herdr.nix) have in
# common: the inside of the box and its resource limits. What makes each one a
# sandbox (privateUsers, privateNetwork, sandbox.interfaces) is spelled out in
# its own file.
let
  # `nixpkgs` for agents' nix shell / nix-shell -p, pinned to this flake's
  # unstable input: nothing to download or evaluate from scratch.
  nixPath = [ "nixpkgs=${inputs.nixpkgs-unstable}" ];

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
  # around the container. Each box links it into its agent user's home.
  notes = pkgs.writeText "agent-notes.md" ''
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
  # For units inside a box: login shells get NIX_PATH and OPENCODE_CONFIG
  # from the system config, services don't.
  inherit nixPath opencodeConfig notes;

  # NixOS module for the inside of a box.
  guest = {
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
      # doesn't exist in the box's network namespace, and the router's DNS is
      # on the blocked LAN.
      useHostResolvConf = false;
      nameservers = [
        "9.9.9.9"
        "1.1.1.1"
      ];
      # Only the host can reach a box anyway (sandbox-net.nix).
      firewall.enable = false;
    };

    # What agents and login sessions get, on top of NixOS's base set (bash,
    # coreutils, curl, grep, sed, tar, ssh, …) and what each box adds.
    # Everything else comes from nix.
    environment.systemPackages = [
      pkgs.unstable.claude-code
      # The way to Muse Spark and other non-Anthropic models: nixpkgs builds
      # it from source, while Meta's own CLI is closed and self-updating.
      pkgs.unstable.opencode
      pkgs.jq
      pkgs.unzip
      pkgs.nodejs
      pkgs.python3
    ];
    environment.variables.OPENCODE_CONFIG = "${opencodeConfig}";

    # Nobody in a box may use it; without it, one setuid-root binary less.
    security.sudo.enable = false;
  };

  # For the end of a box's container@<name> preStart. The start script of
  # NixOS containers runs as root on the host and does mkdir, chmod and touch
  # on these paths inside the box's root FS before nspawn takes over. Root in
  # the box could turn them into symlinks to host paths and reboot the box.
  rootGuard = ''
    declare root
    for p in usr usr/bin etc etc/machine-id var var/lib var/lib/private root; do
      if [[ -L "$root/$p" ]]; then
        echo "$root/$p is a symlink: not starting, the start script would follow it" >&2
        exit 1
      fi
    done
  '';

  # serviceConfig for a box's container@<name> unit, each box on its own.
  # Agents are the most expendable thing on this host. MemoryMax doesn't cover
  # swap. No IOWeight: only BFQ or io.cost honour it, and tortila has neither.
  limits = {
    MemoryHigh = "50%";
    MemoryMax = "60%";
    MemorySwapMax = "4G";
    CPUWeight = 50;
    TasksMax = 4096;
    OOMScoreAdjust = 500;
  };
}
