{
  config,
  lib,
  pkgs,
  ...
}:
let
  tailnet = "shorthair-inconnu.ts.net";
  cloudflare-domain = "netak.li";
  # Tailscale Services hosted on this machine (bare names; units below add
  # the `svc:` prefix where needed). Single source of truth for both the
  # serve and advertise units.
  serveNames = [
    "home"
    "immich"
    "paperless"
    "n8n"
    "stirling"
    "ollama"
    "open-webui"
    "whisper"
    "transmute"
    "hermes"
    "artemon"
  ];
in
{
  _module.args = {
    tailnet = tailnet;
    cloudflare-domain = cloudflare-domain;
  };
  networking.hostName = "tortila";

  ### NICs

  # Disable legacy wireless backend
  networking.useDHCP = false;
  networking.wireless.enable = false;

  # Direct agenix to drop the decrypted configuration exactly where iwd expects it.
  # iwd escapes non-alphanumeric SSID filenames using '=' followed by the lowercase HEX bytes.
  # '•••' -> '=e280a2e280a2e280a2.psk'
  age.secrets.unicode_wifi = {
    file = ../../secrets/home-wifi.psk.age;
    path = "/var/lib/iwd/=e280a2e280a2e280a2.psk";
    mode = "600";
    owner = "root";
    group = "root";
    # Restart iwd daemon automatically when the secret changes
    symlink = false;
  };

  networking.wireless.iwd = {
    enable = true;
    settings = {
      General = {
        # Rely on systemd-networkd for DHCP orchestration
        EnableNetworkConfiguration = false;
      };
    };
  };

  systemd.network = {
    enable = true;

    # Wait for any routable interface before marking network-online.target as successful
    wait-online.anyInterface = true;

    networks."10-ethernet" = {
      # Match standard predictable ethernet interface naming schemes (like eno1)
      matchConfig.Name = "en*";

      networkConfig = {
        DHCP = "yes";
        IPv6PrivacyExtensions = "kernel";
      };

      dhcpV4Config = {
        # Lower metric (higher priority) than the 202 you set for wireless
        RouteMetric = 100;
      };

      # dhcpV6Config = {
      #   RouteMetric = 100;
      # };
      routes = [
        {
          Gateway = "::";
          Metric = 100;
        }
      ];

      linkConfig.RequiredForOnline = "routable";
    };

    networks."20-wireless" = {
      # Match standard predictable wireless interface naming schemes
      matchConfig.Name = "wl*";

      networkConfig = {
        DHCP = "yes";
        # Enable IPv6 Privacy Extensions to prevent hardware MAC tracking across networks
        IPv6PrivacyExtensions = "kernel";
      };

      dhcpV4Config = {
        # Use route metrics to prioritize wired interfaces over wireless if both are connected
        RouteMetric = 202;
      };

      # dhcpV6Config = {
      #   RouteMetric = 202;
      # };

      routes = [
        {
          Gateway = "::";
          Metric = 200;
        }
      ];

      # Ensure the interface is required to be operational before critical downstream daemons start
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # networking.networkmanager.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  ### SSH

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password"; # Root login via keys only for deploy automation
      KbdInteractiveAuthentication = false;
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512" # For solidExplorer
      ];
    };
    extraConfig = ''
      Match User backupreader
        ChrootDirectory /srv/sftp/backupreader
        ForceCommand internal-sftp -R
        AllowTcpForwarding no
        PermitTunnel no
        X11Forwarding no
        PermitTTY no
        GatewayPorts no
    '';
  };

  systemd.tmpfiles.rules = [
    "d /srv/sftp/backupreader 0755 root root -"
  ];

  fileSystems."/srv/sftp/backupreader/laptop" = {
    device = "/backup/laptop";
    fsType = "none";
    options = [
      "bind"
      "ro"
      "noexec"
      "nosuid"
      "nodev"
    ];
  };

  fileSystems."/srv/sftp/backupreader/masterdata" = {
    device = "/backup/masterdata";
    fsType = "none";
    options = [
      "bind"
      "ro"
      "noexec"
      "nosuid"
      "nodev"
    ];
  };

  systemd.services.sshd = {
    serviceConfig = {
      OOMScoreAdjust = -900; # Kernel OOM killer avoids it (-1000 = never kill)
      Nice = -5; # Higher CPU scheduling priority
    };
  };

  programs.ssh = {
    extraConfig = ''
      Match User root
        Host github.com
          User git
          IdentityFile /root/.ssh/ssh_ed25519_github
          IdentitiesOnly yes
    '';

    knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };
  # programs.mosh.enable = true;

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    # tailscale0 is deliberately NOT trusted: every tailnet peer (including
    # compromised devices) gets only the ports listed below, not the whole host.
    trustedInterfaces = [ ];
    # Allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];
    # Loose RPF: host is multihomed (wired + wireless) and an exit node.
    checkReversePath = "loose";
    interfaces."tailscale0" = {
      # Only SSH: every app is served via Tailscale Services (svc:*).
      # tailscaled receives the WireGuard traffic itself, terminates TLS
      # and proxies plaintext to localhost — nothing else needs a
      # firewall port, and per-app ports are gone entirely.
      allowedTCPPorts = [
        22 # SSH — removing this locks you out over the tailnet
      ];
    };
  };

  ### INGRESS

  services.tailscale = {
    enable = true;
    # Unstable daemon: Services cert issuance (TLS on svc: names) is under
    # active development; stable 1.98 fails ACME orders for service names.
    # The serve *module* is identical in both channels, only the daemon matters.
    package = pkgs.unstable.tailscale;
    extraSetFlags = [ "--advertise-exit-node" ];
    extraUpFlags = [ ];
  };
  # 2. Force tailscaled to use nftables (Critical for clean nftables-only systems)
  # This avoids the "iptables-compat" translation layer issues.
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  systemd.services.tailscaled = {
    serviceConfig = {
      OOMScoreAdjust = -900;
      Nice = -5;
    };
  };

  # Every app gets its own MagicDNS name (<service>.<tailnet>) on 443 with
  # a Tailscale-provisioned cert; tailscaled terminates TLS and proxies
  # plaintext HTTP to the local backends. Prefer one entry per service —
  # sharing a single svc: name would lose the unique names and is only
  # useful for HA/failover across hosts, which we don't have.
  #
  # Served purely via CLI-wrapping units below: the NixOS
  # `services.tailscale.serve.services` schema (and raw config files) cannot
  # express the needed combo — `--https=443` TLS termination up front with a
  # plaintext `http://…` backend. The config-file equivalent
  # ("tcp:443" = "https://…") would ALSO require TLS on the backend,
  # which our apps don't speak, and plain "http://…" values are raw L4
  # TCP forwards with no TLS at all.
  # NOTE: the Anki container stays localhost-only on purpose — it is a
  # backend for n8n automation, not something to open even to the tailnet.
  systemd.services.tailscale-serve-l7 =
    let
      tailscale = lib.getExe config.services.tailscale.package;
      https = svc: target: "${tailscale} serve --service=${svc} --https=443 ${target}";
      tcp =
        svc: port: target:
        "${tailscale} serve --service=${svc} --tcp=${toString port} ${target}";
      # NOTE: the SSH endpoint stays a raw L4 forward — no TLS involved.
      endpoints = lib.concatLines [
        (https "svc:home" "http://127.0.0.1:${toString config.services.homepage-dashboard.listenPort}")
        (https "svc:immich" "http://127.0.0.1:${toString config.services.immich.port}")
        (https "svc:paperless" "http://127.0.0.1:${toString config.services.paperless.port}")
        (https "svc:n8n" "http://127.0.0.1:5678")
        (https "svc:stirling" "http://127.0.0.1:2211")
        (https "svc:ollama" "http://127.0.0.1:${toString config.services.ollama.port}")
        (https "svc:open-webui" "http://127.0.0.1:${toString config.services.open-webui.port}")
        (https "svc:whisper" "http://127.0.0.1:2214")
        (https "svc:transmute" "http://127.0.0.1:3313")
        (https "svc:hermes" "http://127.0.0.1:9119")
        (https "svc:artemon" "http://artemon.lan:80")
        (tcp "svc:artemon" 22 "tcp://artemon.lan:22")
      ];
    in
    {
      description = "Create L7 HTTPS endpoints for Tailscale Services";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      # Idempotent: re-running the same serve command is a no-op, and NixOS
      # restarts the unit whenever `script` changes (i.e. on every edit here).
      script = endpoints;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

  # `tailscale serve --service=…` configures AND advertises in one go, but a
  # later `serve reset` (or any state loss) silently drops advertisements —
  # services show "0 hosts" with no trace in the Nix config. This unit
  # re-advertises everything after the L7 unit. Idempotent no-op otherwise.
  # NOTE: advertising is not approval — a fresh host still needs one-time
  # Approve in the admin console (or autoApprovers in the tailnet policy).
  systemd.services.tailscale-serve-advertise = {
    description = "Advertise Tailscale Services from this host";
    after = [ "tailscale-serve-l7.service" ];
    wants = [ "tailscale-serve-l7.service" ];
    wantedBy = [ "multi-user.target" ];
    script = lib.concatMapStrings (name: ''
      ${lib.getExe config.services.tailscale.package} serve advertise svc:${name}
    '') serveNames;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  age.secrets.cloudflared-tortila-tunnel = {
    file = ../../secrets/cloudflared-tortila-tunnel.age;
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    tunnels."81f0efdc-2c1f-4e98-a948-a598866e4039" = {
      credentialsFile = config.age.secrets.cloudflared-tortila-tunnel.path;
      ingress = {
        "pdf.${cloudflare-domain}" = "http://localhost:2211";
        "convert.${cloudflare-domain}" = "http://localhost:3313";

        # n8n: наружу открываются исключительно вебхуки
        "n8n.${cloudflare-domain}" = {
          service = "http://127.0.0.1:5678";
          path = "webhook";
        };
      };
      default = "http_status:404";
    };
  };
}
