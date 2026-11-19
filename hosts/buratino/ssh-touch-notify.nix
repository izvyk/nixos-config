{ pkgs, ... }:

# A desktop notification while ssh or ssh-keygen (git commit signing) waits
# for a touch on the FIDO key. In a terminal they print "Confirm user
# presence..." to stderr; without one (Claude, an IDE, any GUI app) they run
# SSH_ASKPASS with SSH_ASKPASS_PROMPT=none instead and SIGTERM it as soon as
# the key answers or times out. So the notification stays up exactly that long.
#
# The body names the caller from the process tree, plus an optional reason
# the caller passes in SSH_TOUCH_REASON. Both are what the caller claims to
# be: anything running as phil can fake them. They help to notice an
# unexpected request, they don't prove a request is honest.
#
# No passphrase or PIN prompts (no verify-required keys left): any real
# question gets no answer, as it would without SSH_ASKPASS.
let
  ssh-touch-notify = pkgs.writeShellApplication {
    name = "ssh-touch-notify";
    runtimeInputs = with pkgs; [
      libnotify
      glib # gdbus
      procps
      coreutils
    ];
    text = ''
      [ "''${SSH_ASKPASS_PROMPT-}" = none ] || exit 1

      # Us <- ssh / ssh-keygen <- git (or whatever started ssh).
      via=$(ps -o args= -p "$PPID" || true)
      caller_pid=$(ps -o ppid= -p "$PPID" | tr -d ' ' || true)
      caller=$(ps -o args= -p "''${caller_pid:-0}" || true)
      dir=''${PWD/#"$HOME"/\~}

      # The body is markup: escape everything that isn't ours.
      esc() {
        local s=''${1//&/&amp;}
        s=''${s//</&lt;}
        printf '%s' "''${s//>/&gt;}"
      }
      reason=''${SSH_TOUCH_REASON-}
      body=""
      [ -n "$reason" ] && body="<b>$(esc "''${reason:0:200}")</b>"$'\n'
      body+="$(esc "''${caller:0:160}")"$'\n'"in $(esc "$dir")"$'\n'
      body+="<i>$(esc "''${via:0:160}")</i>"

      id=$(notify-send --print-id --urgency=critical --app-name=OpenSSH \
        --icon=dialog-password "Touch your security key" "$body")

      close() {
        gdbus call --session --dest org.freedesktop.Notifications \
          --object-path /org/freedesktop/Notifications \
          --method org.freedesktop.Notifications.CloseNotification "$id" >/dev/null || true
        exit 0
      }
      trap close TERM INT HUP
      # ssh normally kills us; if it dies first, don't leave the banner up.
      while kill -0 "$PPID" 2>/dev/null; do
        sleep 1 &
        wait $! || true
      done
      close
    '';
  };
in
{
  programs.ssh = {
    enableAskPassword = true;
    askPassword = "${ssh-touch-notify}/bin/ssh-touch-notify";
  };
}
