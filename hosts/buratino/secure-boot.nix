# Secure Boot with lanzaboote. It installs systemd-boot and signs it, the
# kernel and the initrd with our own keys, so a tampered /boot (the only
# unencrypted partition) won't boot and can't fish for the LUKS password.
# The systemd-boot settings in default.nix (timeout, editor, console mode,
# generation limit) carry over.
#
# Only our keys are enrolled, not Microsoft's: with those, any
# Microsoft-signed chain (shim → distro GRUB → kernel → unchecked initrd)
# would boot here too. `sbctl enroll-keys` refuses if the TPM event log shows
# option ROMs that would need them. The BIOS supervisor password is what
# keeps Secure Boot from simply being switched off.
#
# No kernel lockdown comes with it (NixOS kernels don't build the LSM), so
# hibernation keeps working.
#
# One-time setup, as root:
#   nix shell nixpkgs#sbctl -c sbctl create-keys   # before the first rebuild
#   nixos-rebuild switch, reboot once with Secure Boot still off
#   sbctl verify                                    # all signed but kernel-*
#   BIOS: set a supervisor password; Secure Boot → Reset to Setup Mode
#   sbctl enroll-keys                               # no --microsoft
#   BIOS: enable Secure Boot; `bootctl status` shows "enabled (user)"
{
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
