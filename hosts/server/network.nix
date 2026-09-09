{
  config,
  lib,
  pkgs,
  ...
}:
let
  tailnet = "shorthair-inconnu.ts.net";
  cloudflare-domain = "tekr.ink";
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
    # Always allow traffic from your Tailscale network
    trustedInterfaces = [ "tailscale0" ];
    # Allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];
    checkReversePath = "loose";
    interfaces."tailscale0" = {
      allowedTCPPorts = [
        443 # Immich
        8443 # Paperless
      ];
    };
  };

  ### INGRESS

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--advertise-exit-node" ];
    extraUpFlags = [ ];

    # Strict privilege separation: Allow only the Caddy user to fetch
    # TLS certificates from the Tailscale socket.
    permitCertUid = config.services.caddy.user;
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

  services.caddy = {
    enable = true;

    # Homepage on 443
    virtualHosts."${config.networking.hostName}.${tailnet}:443" = {
      extraConfig = ''
                tls {
                  get_certificate tailscale
                }
                reverse_proxy 127.0.0.1:${toString config.services.homepage-dashboard.listenPort} {
        	  header_up Host 127.0.0.1
        	  header_up -Origin
        	}
      '';
    };

    # Immich on 7443
    virtualHosts."${config.networking.hostName}.${tailnet}:7443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:${toString config.services.immich.port}
      '';
    };

    # Paperless on 8443
    virtualHosts."${config.networking.hostName}.${tailnet}:8443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:${toString config.services.paperless.port}
      '';
    };

    # n8n on 9443
    virtualHosts."${config.networking.hostName}.${tailnet}:9443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:5678
      '';
    };

    # Vaultwarden on 10443
    # virtualHosts."${config.networking.hostName}.${tailnet}:10443" = {
    #   extraConfig = ''
    #     tls {
    #       get_certificate tailscale
    #     }
    #     reverse_proxy 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
    #   '';
    # };

    # StirlingPDF on 11443
    virtualHosts."${config.networking.hostName}.${tailnet}:11443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:2211
      '';
    };

    # ollama on 12443
    virtualHosts."${config.networking.hostName}.${tailnet}:12443" = {
      extraConfig = ''
                log
                tls {
                  get_certificate tailscale
                }
                reverse_proxy 127.0.0.1:${toString config.services.ollama.port} {
        	  header_up Host 127.0.0.1:${toString config.services.ollama.port}
        	  header_up -Origin
        	}
      '';
    };

    # open-webui on 13443
    virtualHosts."${config.networking.hostName}.${tailnet}:13443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:${toString config.services.open-webui.port}
      '';
    };

    # whisper-cli on 14443
    virtualHosts."${config.networking.hostName}.${tailnet}:14443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:2214
      '';
    };

    # Transmute.sh on 15443
    virtualHosts."${config.networking.hostName}.${tailnet}:15443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:3313
      '';
    };

    # Hermes dashboard on 16443
    virtualHosts."${config.networking.hostName}.${tailnet}:16443" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
        reverse_proxy 127.0.0.1:9119
      '';
    };
  };

  age.secrets.cloudflared-tekr-tunnel = {
    file = ../../secrets/cloudflared-tekr-home-tunnel.age;
    owner = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    tunnels."01d101f2-404e-48f3-a669-32d39496ee5a" = {
      credentialsFile = config.age.secrets.cloudflared-tekr-tunnel.path;
      ingress = {
        "pdf.${cloudflare-domain}" = "http://localhost:2211";
        "convert.${cloudflare-domain}" = "http://localhost:3313";
      };
      default = "http_status:404";
    };
  };
}
