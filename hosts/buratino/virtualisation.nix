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
      # UEFI and Secure Boot firmware are provided by QEMU automatically.
    };
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
