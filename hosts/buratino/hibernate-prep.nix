# Laptop-specific: make suspend-then-hibernate more likely to succeed.
#
# Background: hibernation failed with -ENOMEM ("Error -12 creating image")
# when ~8GB was in use — the kernel needs used ≈ free to snapshot. The
# preallocation grind froze the desktop for ~90s before failing.
#
# This hook runs in systemd-sleep's "pre" phase (as root) and just prepares
# memory: sync + drop caches + compaction, then logs the resulting state.
# If hibernation still fails, systemd itself falls back to suspend
# ("Couldn't hibernate, will try to suspend again"), so we don't abort here —
# a failing hook would cancel the whole sleep and leave the machine awake.
{
  pkgs,
  ...
}:

{
  environment.etc."systemd/system-sleep/hibernate-prep" = {
    mode = "0555";
    text = ''
      #!${pkgs.bash}/bin/bash
      [ "$1" = "pre" ] || exit 0
      case "$2" in
        hibernate|suspend-then-hibernate) ;;
        *) exit 0 ;;
      esac

      ${pkgs.coreutils}/bin/sync
      # Reclaim page cache and compact memory to maximize freeable pages
      echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
      echo 1 > /proc/sys/vm/compact_memory 2>/dev/null

      ${pkgs.gawk}/bin/awk '/Mem(Total|Available|Free)|SwapFree/ {print $1, $2}' /proc/meminfo \
        | ${pkgs.coreutils}/bin/tr '\n' ' ' \
        | ${pkgs.util-linux}/bin/logger -t hibernate-prep
      exit 0
    '';
  };
}
