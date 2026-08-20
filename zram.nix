{
  pkgs,
}:
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100; # Maximum priority. Kernel uses this first.
  };

  # Dynamically allocate the physical swapfile ONLY during hibernation lifecycles.
  # The swapfile is completely invisible to the kernel during normal runtime.
  systemd.services.systemd-hibernate.serviceConfig = {
    ExecStartPre = "${pkgs.util-linux}/bin/swapon /swap/swapfile";
    ExecStopPost = "${pkgs.util-linux}/bin/swapoff /swap/swapfile";
  };

  systemd.services.systemd-suspend-then-hibernate.serviceConfig = {
    ExecStartPre = "${pkgs.util-linux}/bin/swapon /swap/swapfile";
    ExecStopPost = "${pkgs.util-linux}/bin/swapoff /swap/swapfile";
  };

  systemd.services.systemd-logind = {
    environment = {
      SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK = "1";
    };
  };
}
