# Laptop-specific: make suspend-then-hibernate survivable.
#
# Background: hibernation failed with -ENOMEM ("Error -12 creating image")
# when ~8GB was in use — the kernel needs used ≈ free to snapshot. The
# preallocation grind froze the desktop for ~90s before failing.
#
# This hook runs in systemd-sleep's "pre" phase (as root):
#  1. sync + drop caches + compact — buys back freeable pages so the image fits
#  2. guard — if used memory is still > 90% of free pages, the snapshot would
#     obviously fail, so exit 1 to abort the sleep attempt (logged) instead of
#     freezing the desktop for a doomed hibernation.
#
# Note: in suspend-then-hibernate the hooks run once at the initial suspend;
# the wake-path hibernation (lid opened after the 2h delay) uses the memory
# state from suspend time — which is exactly what this guard checks.
{
  pkgs,
  lib,
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

      mem_total=$(${pkgs.gawk}/bin/awk '/MemTotal/ {print int($2)}' /proc/meminfo)
      mem_free=$(${pkgs.gawk}/bin/awk '/MemFree/ {print int($2)}' /proc/meminfo)
      mem_used=$((mem_total - mem_free))

      # Snapshot requires used ≈ free; 90% gives headroom for kernel/GPU pages
      if [ "$mem_used" -gt $((mem_free * 90 / 100)) ]; then
        ${pkgs.util-linux}/bin/logger -t hibernate-prep \
          "hibernation would fail (-ENOMEM): $((mem_used / 1024))MB used vs $((mem_free / 1024))MB free; aborting sleep attempt"
        exit 1
      fi

      ${pkgs.util-linux}/bin/logger -t hibernate-prep "prepared for hibernation: $((mem_used / 1024))MB used, $((mem_free / 1024))MB free"
      exit 0
    '';
  };
}