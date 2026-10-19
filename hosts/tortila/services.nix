{
  config,
  lib,
  pkgs,
  tailnet,
  cloudflare-domain,
  ...
}:
let
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin";
    sha256 = "0ywqxbziyp2bv72riyjpw4brk9v46d4cfbjfwqvvjrrq0srakqqv";
  };
  svc = name: "https://${name}.${tailnet}";
in
{
  age.secrets.homepage_env = {
    file = ../../secrets/homepage-env.age;
    mode = "0400";
    owner = "root";
  };

  services.homepage-dashboard = {
    enable = true;
    listenPort = 2200;
    allowedHosts = "localhost,127.0.0.1,home.${tailnet}";

    # Point this to a secure file outside the nix store (e.g., via sops-nix or agenix)
    environmentFiles = [ config.age.secrets.homepage_env.path ];

    services = [
      {
        "Infrastructure & Core" = [
          {
            "Caddy" = {
              icon = "sh-caddy";
              # You can leave href empty or point it to a specific local site
              description = "Reverse Proxy";
              widget = {
                type = "caddy";
                url = "http://127.0.0.1:2019";
                # Optional: limit which fields are shown
                # fields = ["upstreams" "requests" "requests_failed"];
              };
            };
          }
          # {
          #   "Caddy" = {
          #     description = "Reverse Proxy & Web Server";
          #     href = "https://caddy.yourdomain.com";
          #     icon = "sh-caddy";
          #   };
          # }
          # {
          #   "Syncthing" = {
          #     description = "Continuous File Synchronization";
          #     href = "https://syncthing.yourdomain.com";
          #     icon = "sh-syncthing";
          #   };
          # }
          {
            "Vaultwarden" = {
              description = "Password Management";
              href = svc "vaultwarden";
              icon = "sh-bitwarden"; # Or sh-vaultwarden
            };
          }
        ];
      }
      {
        "Media & Documents" = [
          {
            "Immich" = {
              description = "Self-hosted Photo & Video Backup";
              href = svc "immich";
              icon = "sh-immich";
              # widget = {
              #   type = "immich";
              #   # Use the internal port/URL so Homepage can reach it directly
              #   url = "http://localhost:2283";
              #   key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
              #   version = 2; # Required for Immich v1.118.2 and newer
              # };
            };
          }
          {
            "Paperless-ngx" = {
              description = "Document Management & OCR";
              href = svc "paperless";
              icon = "sh-paperless-ngx";
              # widget = {
              #   type = "paperlessngx";
              #   url = "http://localhost:${toString config.services.paperless.port}";
              #   key = "{{HOMEPAGE_VAR_PAPERLESS_KEY}}";
              # };
            };
          }
          {
            "Stirling-PDF" = {
              description = "PDF Manipulation Tool";
              href = svc "stirling";
              icon = "sh-stirling-pdf";
            };
          }
        ];
      }
      {
        "AI & Automation" = [
          {
            "Ollama" = {
              description = "Local LLM Runner";
              href = svc "ollama";
              icon = "sh-ollama";
            };
          }
          {
            "Whisper" = {
              description = "Local Speech-To-Text Model";
              href = svc "whisper";
              icon = "sh-openai";
            };
          }
          {
            "Open-WebUI" = {
              description = "AI Chat Interface";
              href = svc "open-webui";
              icon = "sh-open-webui";
            };
          }
          {
            "n8n" = {
              description = "Workflow Automation";
              href = svc "n8n";
              icon = "sh-n8n";
            };
          }
          {
            "Hermes" = {
              description = "Hermes Agent dashboard";
              href = svc "hermes";
              icon = "sh-hermes-agent";
            };
          }
          {
            "Anki" = {
              description = "Headless Anki (AnkiConnect API)";
              href = svc "anki";
              icon = "sh-anki";
            };
          }
        ];
      }
    ];

    widgets = [
      {
        search = {
          provider = "google";
          showSearchSuggestions = true;
          target = "_blank";
        };
      }
      {
        resources = {
          cpu = true;
          cputemp = true;
          memory = true;
          disk = "/";
        };
      }
      #      {
      #        strelaysrv = {
      #   url = "http://localhost:2019";
      # };
      #      }
      #      {
      #        tailscale = {
      #   deviceid = "http://localhost:2019";
      #   key = "";
      # };
      #      }
    ];
  };

  services.immich = {
    enable = true;
    port = 2209;
    host = "127.0.0.1";
    # host = "0.0.0.0";
    # openFirewall = true;

    environment.IMMICH_LOG_LEVEL = "warn";
    #mediaLocation = "/var/lib/immich";
  };
  services.redis.servers.immich.logLevel = "warning";

  services.paperless = {
    enable = true;
    consumptionDirIsPublic = true;
    # address = "<machine ip>";
    address = "127.0.0.1";
    port = 2208;
    settings = {
      PAPERLESS_CONSUMER_IGNORE_PATTERN = [
        ".DS_STORE/*"
        "desktop.ini"
      ];
      PAPERLESS_OCR_LANGUAGE = "deu+eng+rus";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };
      # PAPERLESS_URL = "https://paperless.example.com";
      PAPERLESS_URL = svc "paperless";
      PAPERLESS_CORS_ALLOWED_HOSTS = svc "paperless";
    };
  };

  age.secrets."n8n-runners-auth-token" = {
    file = ../../secrets/n8n-runners-auth-token.age;
    owner = "n8n";
    group = "n8n";
    mode = "0400";
  };

  services.n8n = {
    enable = true;
    environment = {
      N8N_SECURE_COOKIE = "false";
      WEBHOOK_URL = "https://n8n.${cloudflare-domain}/";
      N8N_EDITOR_BASE_URL = svc "n8n";
      N8N_RUNNERS_ENABLED = "true";
      N8N_RUNNERS_AUTH_TOKEN_FILE = config.age.secrets."n8n-runners-auth-token".path;
    };

    # Built-in task runner support (nixos-26.05)
    taskRunners = {
      enable = true;
      environment = {
        # Optional overrides — defaults derived from broker settings automatically
        # N8N_RUNNERS_TASK_TIMEOUT = "300";
        N8N_RUNNERS_MAX_CONCURRENCY = "10";
      };
    };
  };

  # services.vaultwarden = {
  #   enable = false;
  #   config = {
  #     DOMAIN = "https://${config.networking.hostName}.${tailnet}";
  #     SIGNUPS_ALLOWED = false;
  #
  #     # Vaultwarden recommends running behind a reverse proxy, the configureNginx option can be used for that.
  #     ROCKET_ADDRESS = "127.0.0.1";
  #     ROCKET_PORT = 2210;
  #
  #     ROCKET_LOG = "critical";
  #   };
  # };

  services.stirling-pdf = {
    enable = true;
    package = pkgs.unstable.stirling-pdf;
    environment = {
      SERVER_PORT = 2211;
    };
  };

  # services.ntfy-sh.enable = true;

  # ----------------------------------------------------
  # LOCAL AI STACK (OLLAMA + OPEN WEBUI)
  # ----------------------------------------------------

  services.ollama = {
    enable = true;
    # We omit 'package' or 'acceleration' here. Ollama will default to
    # the standard CPU package, which is exactly what we want for the M720q.

    host = "127.0.0.1";
    port = 2212;

    loadModels = [
      "gemma3:4b"
      "dolphin3:8b"
      "qwen2.5-coder:7b"
      "qwen2.5-coder:1.5b"
      "dolphin-mistral"
      "wizardlm-uncensored"
      "huihui_ai/dolphin3-abliterated"
    ];

    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "5m"; # unload model after 5min idle to save RAM
      OLLAMA_NUM_THREADS = "6";
      # Allow browser requests served via Tailscale Services.
      # Note: OLLAMA_HOST stays 127.0.0.1 — only the UI/API go through tailscaled.
      OLLAMA_ORIGINS = "http://localhost,https://localhost,http://localhost:*,https://localhost:*,http://127.0.0.1,https://127.0.0.1,http://127.0.0.1:*,https://127.0.0.1:*,${svc "ollama"}";
    };
  };

  services.open-webui = {
    enable = true;
    port = 2213;
    environment = {
      # OLLAMA_API_BASE_URL = "https://${config.networking.hostName}.${tailnet}";
      # Disables the login screen so you can use it immediately locally
      WEBUI_AUTH = "False";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      OLLAMA_API_BASE_URL = "http://${toString config.services.ollama.host}:${toString config.services.ollama.port}";
    };
  };

  systemd.services.whisper-api = {
    description = "Whisper.cpp OpenAI-Compatible REST API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      # Use a dynamic user for security
      DynamicUser = true;

      # The whisper-server binary provides the API
      # -m : Path to your model
      # --host 0.0.0.0 : Bind to all network interfaces so you can access it remotely
      # --port 8080 : The port to listen on
      ExecStart = ''
        ${pkgs.whisper-cpp}/bin/whisper-server \
          -m ${whisperModel} \
          --host 127.0.0.1 \
          --port 2214 \
          -t 4 
      '';
      Restart = "always";
    };
  };

  # Fix double-CoW: use btrfs driver instead of overlay2
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      "storage-driver" = "btrfs";
    };
  };

  # Persistent data directories, created before containers start
  systemd.tmpfiles.rules = [
    "d /var/lib/transmute 0750 root root -"
    "d /var/lib/anki 0750 root root -"
    "d /var/lib/anki-export 0750 root root -"
  ];

  age.secrets.cloudflared-convert-oidc = {
    file = ../../secrets/cloudflared-convert-oidc.age;
    owner = "root";
    mode = "0400";
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      transmute = {
        image = "ghcr.io/transmute-app/transmute:latest";
        autoStart = true;
        ports = [ "127.0.0.1:3313:3313" ];
        volumes = [
          "/var/lib/transmute:/app/data"
        ];
        environmentFiles = [
          config.age.secrets.cloudflared-convert-oidc.path # contains OIDC_CLIENT_SECRET
        ];
        environment = {
          # App URL — must match what Cloudflare redirects to
          APP_URL = "https://convert.${cloudflare-domain}";

          # OIDC config
          OIDC_DISPLAY_NAME = "Google";
          OIDC_CLIENT_ID = "3c10529ab81a022a4fa7ac1a5dab479a38be2a51fca8ab7d41e250a0cb9f0944";
          OIDC_ISSUER_URL = "https://izvyk.cloudflareaccess.com/cdn-cgi/access/sso/oidc/3c10529ab81a022a4fa7ac1a5dab479a38be2a51fca8ab7d41e250a0cb9f0944";
          OIDC_AUTO_CREATE_USERS = "true";
          OIDC_AUTO_LAUNCH = "true";

          # Disable local password auth - OIDC only
          ALLOW_REGISTRATION = "false";
        };
      };

      hermes = {
        image = "nousresearch/hermes-agent:v2026.8.3";
        cmd = [
          "gateway"
          "run"
        ];
        ports = [
          "127.0.0.1:9119:9119" # web dashboard
          "127.0.0.1:8642:8642" # gateway API (the dashboard talks to this)
        ];
        volumes = [ "/var/lib/hermes:/opt/data" ];
        environment = {
          HERMES_DASHBOARD = "1";
        };
        environmentFiles = [ config.age.secrets.hermes-env.path ];
      };

      # Headless Anki with AnkiConnect on :8765.
      # NOTE: the image cannot log into AnkiWeb on its own. After first deploy,
      # connect once via VNC (QT_QPA_PLATFORM defaults to "vnc", port 5900) and
      # enable AnkiWeb sync in the profile (Tools → Preferences → Syncing).
      # The login token then persists in /var/lib/anki, so sync survives restarts.
      anki = {
        image = "thisisnttheway/headless-anki:latest";
        autoStart = true;
        ports = [
          "127.0.0.1:8765:8765" # AnkiConnect API
          "127.0.0.1:5900:5900" # VNC for one-time AnkiWeb login / debugging
        ];
        volumes = [
          "/var/lib/anki:/data"
          "/var/lib/anki-export:/export"
        ];
      };
    };
  };

  age.secrets.hermes-env = {
    file = ../../secrets/hermes-env.age;
  };
  # virtualisation.oci-containers = {
  #     backend = "docker";
  #     containers.transmute = {
  #       image = "ghcr.io/transmute-app/transmute:latest";
  #       autoStart = true;
  #       ports = [ "3313:3313" ];
  #       volumes = [
  #         "/var/lib/transmute:/app/data"
  #       ];
  #       environment = {
  #         # Optional: set auth, workers, etc.
  #         # AUTH_ENABLED = "true";
  #       ];
  #     };
  #   };
}
