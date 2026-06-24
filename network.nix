{
  config,
  lib,
  pkgs,
  ...
}:

let
in
{
  networking.hostName = "NixPC";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  networking.networkmanager = {
    enable = true;
    wifi.powersave = true;
    wifi.backend = "iwd";
    plugins = with pkgs; [
      networkmanager-openvpn
    ];
  };

  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.AddressRandomization = "network";
      Network = {
        EnableIPv6 = true;
        RoutePriorityOffset = 300;
      };
      Settings = {
        AutoConnect = true;
      };
    };
  };

  # systemd.services.NetworkManager-wait-online.enable = false;
  services.avahi.enable = false;
  systemd.services.ModemManager.enable = false;
  # systemd.services.tailscaled.serviceConfig.Type = lib.mkForce "simple";
  services.resolved.enable = true;

  programs.ssh.extraConfig = ''
    Match User root
      Host github.com
        User git
        IdentityFile /root/.ssh/ssh_ed25519_github
        IdentitiesOnly yes
  '';

  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  # services.dae = {
  #   enable = true;
  #   # Point to a file outside the Nix store to keep your V2Ray key secret
  #   configFile = "/etc/dae/config.dae";
  # };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  services.tailscale.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    # Always allow traffic from your Tailscale network
    trustedInterfaces = [ "tailscale0" ];
    # Allow the Tailscale UDP port through the firewall
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # NixOS firewall will block wg traffic because of rpfilter
  networking.firewall.checkReversePath = "loose";

  # 2. Force tailscaled to use nftables (Critical for clean nftables-only systems)
  # This avoids the "iptables-compat" translation layer issues.
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

}
