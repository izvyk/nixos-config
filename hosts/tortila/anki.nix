# Headless Anki from nixpkgs with AnkiConnect on 127.0.0.1:8765, for n8n.
#
# Anki is a GUI app; it runs here on Qt's offscreen platform. Nothing can
# click its dialogs, so anki-headless.py (Anki's own library, same version)
# does what would need one:
#   - `init` (every start): prefs + profile, so no first-run language picker;
#   - `doas anki-headless login`: AnkiWeb login + first download;
#   - `doas anki-headless download`: take AnkiWeb's copy when AnkiWeb demands a
#     one-way full sync (e.g. a note type was edited on the phone). Anki would
#     ask in an invisible dialog; until then n8n keeps adding cards, but
#     syncing stops. A download discards anything not yet synced.
# Anki syncs by itself on start and stop; n8n can also call AnkiConnect `sync`.
{ pkgs, ... }:
let
  stateDir = "/var/lib/anki";

  anki = pkgs.anki.withAddons [
    (pkgs.ankiAddons.anki-connect.withConfig {
      config = {
        apiKey = null;
        apiLogPath = null;
        ignoreOriginList = [ ];
        webBindAddress = "127.0.0.1";
        webBindPort = 8765;
        webCorsOriginList = [ "http://localhost" ];
      };
    })
  ];

  # Run with Anki stopped (it holds the collection open).
  script = pkgs.writeText "anki-headless.py" ''
    import getpass
    import sys

    import anki.lang
    from anki.collection import Collection
    from aqt.profiles import ProfileManager

    PROFILE = "User 1"


    def profile_manager(base: str) -> ProfileManager:
        anki.lang.set_lang("en_US")
        pm = ProfileManager(ProfileManager.get_created_base_folder(base))
        pm.setupMeta()
        pm.meta["firstRun"] = False  # no language picker, no "new profile" flow
        pm.setLang("en_US")
        pm.set_update_check(False)  # Nix ships Anki; nobody can click "update"
        if PROFILE not in pm.profiles():
            pm.create(PROFILE)
        pm.load(PROFILE)
        pm.save()
        return pm


    def download(pm: ProfileManager, col: Collection, server_media_usn=None) -> None:
        print("Downloading the collection from AnkiWeb…")
        col.close_for_full_sync()
        col.full_upload_or_download(
            auth=pm.sync_auth(), server_usn=server_media_usn, upload=False
        )
        col.reopen(after_full_sync=True)


    def sync(pm: ProfileManager, col: Collection) -> None:
        out = col.sync_collection(pm.sync_auth(), pm.media_syncing_enabled())
        pm.set_host_number(out.host_number)
        if out.new_endpoint:
            pm.set_current_sync_url(out.new_endpoint)
        pm.save()
        if out.server_message:
            print("AnkiWeb says:", out.server_message)
        req = out.required
        if req in (out.NO_CHANGES, out.NORMAL_SYNC):
            print("Synced.")
        elif req == out.FULL_UPLOAD:
            # AnkiWeb is empty: never overwrite it from a server-side profile.
            sys.exit("AnkiWeb has no collection; not uploading. Sync once from a real Anki first.")
        else:
            download(pm, col, out.server_media_usn if pm.media_syncing_enabled() else None)
            print("Done.")


    def main() -> None:
        if len(sys.argv) != 3 or sys.argv[1] not in ("init", "login", "download"):
            sys.exit(f"usage: {sys.argv[0]} init|login|download BASE_DIR")
        cmd, base = sys.argv[1], sys.argv[2]
        pm = profile_manager(base)
        if cmd == "init":
            return

        col = Collection(pm.collectionPath())
        try:
            if cmd == "login":
                user = input("AnkiWeb email: ").strip()
                password = getpass.getpass("AnkiWeb password: ")
                auth = col.sync_login(user, password, pm.sync_endpoint())
                pm.set_sync_key(auth.hkey)
                pm.set_sync_username(user)
                pm.save()
                print("Logged in.")
            elif not pm.sync_auth():
                sys.exit("Not logged in; run `login` first.")
            sync(pm, col)
        finally:
            col.close()


    main()
  '';

  # Anki's Python library, run by the same interpreter Anki is built with.
  ankiPython = pkgs.writeShellScript "anki-headless-py" ''
    export PYTHONPATH=${pkgs.anki.lib}/${pkgs.python3.sitePackages}
    export QT_QPA_PLATFORM=offscreen
    exec ${pkgs.python3}/bin/python3 ${script} "$@"
  '';

  anki-headless = pkgs.writeShellApplication {
    name = "anki-headless";
    runtimeInputs = [
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      case "''${1:-}" in
        login | download) ;;
        *)
          echo "usage: doas anki-headless login|download" >&2
          exit 2
          ;;
      esac
      [ "$(id -u)" -eq 0 ] || { echo "run as root: doas anki-headless $1" >&2; exit 1; }
      # Anki holds the collection open: stop it, and start it again however
      # the script ends.
      systemctl stop anki.service
      trap 'systemctl start anki.service' EXIT
      runuser -u anki -- ${ankiPython} "$1" ${stateDir}
    '';
  };
in
{
  users.users.anki = {
    isSystemUser = true;
    group = "anki";
    home = stateDir;
  };
  users.groups.anki = { };

  environment.systemPackages = [ anki-headless ];

  systemd.services.anki = {
    description = "Headless Anki with AnkiConnect on 127.0.0.1:8765";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      HOME = stateDir;
      QT_QPA_PLATFORM = "offscreen";
    };
    serviceConfig = {
      User = "anki";
      Group = "anki";
      StateDirectory = "anki";
      StateDirectoryMode = "0700";
      ExecStartPre = "${ankiPython} init ${stateDir}";
      ExecStart = "${anki}/bin/anki -b ${stateDir}";
      Restart = "on-failure";
      RestartSec = 10;

      # Hardening. Not MemoryDenyWriteExecute: QtWebEngine's V8 needs W+X
      # pages. Namespaces stay allowed: Chromium's sandbox uses them.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
      RestrictRealtime = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
    };
  };
}
