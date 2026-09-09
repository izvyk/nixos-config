let
  # Laptop host key (cat /etc/ssh/ssh_host_ed25519_key.pub)
  laptopRoot = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzdcY0w+18146cN/pBejk+2H5MifrHFvDbNyYPXIgIf root@NixPC";
  # Server host key
  serverRoot = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDPI3xUUvndkvdm2DiHKAl+7pu6D9k3WsrPwLyfBHpTe root@nixos";
in
{
  # Laptop secrets
  "syncthing-cert.age".publicKeys = [ laptopRoot ];
  "syncthing-key.age".publicKeys = [ laptopRoot ];
  "btrbk-ssh-key.age".publicKeys = [ laptopRoot ];

  # Server secrets
  "home-wifi.psk.age".publicKeys = [ serverRoot ];
  "user-dev-password.age".publicKeys = [ serverRoot ];
  "homepage-env.age".publicKeys = [ serverRoot ];
  "cloudflared-oauth.age".publicKeys = [ serverRoot ];
  "cloudflared-tekr-home-tunnel.age".publicKeys = [ serverRoot ];
  "cloudflared-convert-oidc.age".publicKeys = [ serverRoot ];
  "n8n-runners-auth-token.age".publicKeys = [ serverRoot ];
  "hermes-env.age".publicKeys = [ serverRoot ];
  "backup-luks.age".publicKeys = [ serverRoot ];
}