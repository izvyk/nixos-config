# Laptop-specific: keep zswap out of the way while hibernation evicts memory.
#
# Evicted pages would stay in RAM in zswap's pool and still count towards the
# image, ending in "Error -12 creating image". With zswap off the same desktop
# needed 6.8 GiB instead of 8.9 GiB; the limit is about 7.7 GiB.
#
# This hook runs in systemd-sleep's "pre" and "post" phases (as root). If
# hibernation still fails, systemd itself falls back to suspend ("Couldn't
# hibernate, will try to suspend again"), so we don't abort here.
{
  pkgs,
  ...
}:

{
  environment.etc."systemd/system-sleep/hibernate-prep" = {
    mode = "0555";
    text = ''
      #!${pkgs.bash}/bin/bash
      case "$2" in
        hibernate|suspend-then-hibernate) ;;
        *) exit 0 ;;
      esac

      case "$1" in
        pre)
          echo N > /sys/module/zswap/parameters/enabled
          ${pkgs.gawk}/bin/awk '/Mem(Total|Available|Free)|SwapFree/ {print $1, $2}' /proc/meminfo \
            | ${pkgs.coreutils}/bin/tr '\n' ' ' \
            | ${pkgs.util-linux}/bin/logger -t hibernate-prep
          ;;
        post)
          echo Y > /sys/module/zswap/parameters/enabled
          ;;
      esac
      exit 0
    '';
  };
}
