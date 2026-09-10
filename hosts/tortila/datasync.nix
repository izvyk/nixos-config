{
  config,
  pkgs,
  lib,
  ...
}:
let
  laptop-btrbk-ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEYWZRLwcu6Q/TkiMYKxyNpQI8sUJnnv5pgo6ewfBpLT btrbk@NixPC";
  disk = "/dev/disk/by-id/ata-ST1000LM035-1RK172_ZDE7MS86";
in
{
  age.secrets.backup-luks = {
    file = ../../secrets/backup-luks.age;
    owner = "root";
    mode = "0400";
  };

  environment.etc.crypttab.text = ''
    cryptbackup UUID=35f3946f-aae9-4f3e-b652-ff3bce457d2f ${config.age.secrets.backup-luks.path} luks,nofail,noauto,timeout=10
  '';

  fileSystems."/backup" = {
    device = "/dev/mapper/cryptbackup";
    fsType = "btrfs";
    options = [
      "subvol=/"
      "compress=zstd:3"
      "noatime"
      "nossd"
      # "commit=120"
      "nofail"
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=15min"
      "x-systemd.device-timeout=30s"
      "x-systemd.requires=systemd-cryptsetup@cryptbackup.service"
    ];
  };

  # systemd.services.backup-hdd-luks-close = {
  #   description = "closing luks on fs unmount";
  #   after = [ "backup.mount" ];
  #   partOf = [ "backup.mount" ];
  #   wantedBy = [ "backup.mount" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     ExecStop = "/run/current-system/sw/bin/systemctl stop systemd-cryptsetup@cryptbackup.service";
  #   };
  # };

  # systemd.targets."backup-luks-closer" = {
  #   description = "Propagates stop from mount to LUKS without deadlocks";
  #   # Жестко привязываемся к жизни точки монтирования
  #   wantedBy = [ "backup.mount" ];
  #   bindsTo = [ "backup.mount" ];
  #   after = [ "backup.mount" ];
  #
  #   # ВОТ ОНА, МАГИЯ: Когда этот таргет останавливается (потому что останавливается mount),
  #   # он принудительно закидывает cryptsetup в очередь на остановку.
  #   unitConfig.PropagatesStopTo = "systemd-cryptsetup@cryptbackup.service";
  # };

  systemd.services.backup-hdd-power = {
    description = "APM while backup is mounted, standby when it's not";
    before = [ "backup.mount" ];
    partOf = [ "backup.mount" ];
    wantedBy = [ "backup.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.hdparm}/bin/hdparm -B 254 -S 0 ${disk}";
      ExecStop = "${pkgs.hdparm}/bin/hdparm -y ${disk}";
    };
  };

  services.btrbk = {
    extraPackages = [ pkgs.mbuffer ];
    sshAccess = [
      {
        key = "${laptop-btrbk-ssh}";
        roles = [
          "info"
          "target"
          "delete"
        ];
      }
    ];
  };

  # services.udev.extraRules = ''
  #   ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", RUN+="${pkgs.hdparm}/bin/hdparm -B 127 -S 180 /dev/%k"
  # '';
  #
  # services.smartd = {
  #   enable = true;
  #   defaults = "-a -n standby,q";
  # };
  #
  # services.btrfs.autoScrub.fileSystems = [ "/" ]; # not /backup



  # services.syncthing = {
  #   enable = true;
  #   user = "izvyk";
  #   group = "users";
  #   dataDir = "/home/izvyk"; # Default folder for new synced folders
  #   configDir = "/home/izvyk/.config/syncthing"; # Folder for Syncthing's settings and keys
  #   cert = config.age.secrets."syncthing-cert".path;
  #   key = config.age.secrets."syncthing-key".path;
  # };
  #
  # age.secrets."syncthing-cert" = {
  #   file = ../../secrets/syncthing-cert.age;
  #   owner = "izvyk";
  #   group = "users";
  # };
  #
  # age.secrets."syncthing-key" = {
  #   file = ../../secrets/syncthing-key.age;
  #   owner = "izvyk";
  #   group = "users";
  # };
}
