{
  lib,
  pkgs,
  username,
  ...
}:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
      # UEFI and Secure Boot firmware are provided by QEMU automatically.
    };
  };

  # Guests need DHCP and DNS on the host; libvirt handles NAT and forwarding.
  networking.firewall.interfaces.virbr0 = {
    allowedUDPPorts = [ 53 67 ];
    allowedTCPPorts = [ 53 ];
  };

  # Start libvirt on demand rather than at boot.
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];

  programs.virt-manager.enable = true;

  users.users.${username}.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  # Attach as a second CD-ROM to load storage/network drivers during Windows setup.
  environment.etc."libvirt/virtio-win.iso".source = pkgs.virtio-win.src;
}
