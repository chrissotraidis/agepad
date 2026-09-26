#!/bin/zsh
# AgePad on a physical iPad, run from the Mac that owns the Steam copy.
#   scripts/agepad-ipad.sh check            what is ready and what is missing
#   scripts/agepad-ipad.sh build            build, sign and install the app (in place, keeps saves)
#   scripts/agepad-ipad.sh pair             once, over USB: let the iPad reach this Mac's Steam over Wi-Fi
#   scripts/agepad-ipad.sh install-helper   run the Mac helper automatically at login (tap-to-play)
#   scripts/agepad-ipad.sh serve            run the Mac helper in this window instead
#   scripts/agepad-ipad.sh play [minutes]   engineering: start the game from the Mac over USB
#   scripts/agepad-ipad.sh logs             copy the last session's logs to generated/ipad-logs/
# Settings (environment): AGEPAD_UDID, AGEPAD_CANDIDATE (Simulator candidate root),
# AGEPAD_IPC (IPC build), AGEPAD_PROFILE, AGEPAD_IDENTITY, AGEPAD_DIAGNOSTICS=1.
set -u
ROOT=${0:A:h:h}; cd $ROOT
BUNDLE=local.agepad.device-de-probe
STEAM_APP="$HOME/Library/Application Support/Steam/steamapps/common/AoE2DE"
CANDIDATE=${AGEPAD_CANDIDATE:-generated/de-candidate-20260924-responder}
IPC=${AGEPAD_IPC:-generated/de-device-ipc-20260926off}
STATE="$HOME/Library/Application Support/AgePad"
HELPER_PORT=61343
AGENT="$HOME/Library/LaunchAgents/local.agepad.helper.plist"
ok()   { print -P "  %F{green}✓%f $1"; }
bad()  { print -P "  %F{red}✗%f $1"; print "      → $2"; FAILED=1; }
udid() {
  [[ -n ${AGEPAD_UDID:-} ]] && { print $AGEPAD_UDID; return; }
  xcrun devicectl list devices --json-output /tmp/agepad-devices.json >/dev/null 2>&1
  # First paired physical iPad reachable by cable or network (Simulators are
  # listed too and are skipped; the tunnel itself opens on demand).
  python3 -c "import json;d=json.load(open('/tmp/agepad-devices.json'))['result']['devices'];print(next((x['hardwareProperties']['udid'] for x in d if x['hardwareProperties'].get('reality')=='physical' and x['hardwareProperties'].get('deviceType')=='iPad' and x['connectionProperties'].get('pairingState')=='paired' and x['connectionProperties'].get('transportType')),''))" 2>/dev/null
}
afc() { # afcclient without hanging when the device stops answering
  local out=$(mktemp); ( afcclient -u $UDID --container $BUNDLE > $out 2>&1 ) & local pid=$!
  for i in {1..20}; do kill -0 $pid 2>/dev/null || break; sleep 0.5; done; kill $pid 2>/dev/null; cat $out; rm -f $out
}
check() {
  FAILED=0; print "AgePad setup check"
  [[ -d "$STEAM_APP/AgeOfEmpires2Data" ]] && ok "Mac Steam copy of AoE II: DE found" \
    || bad "Mac Steam copy of AoE II: DE not found" "Install Age of Empires II: DE in Steam for Mac (you must own it)."
  pgrep -q steam_osx && ok "Steam is running on this Mac" || bad "Steam is not running" "Open Steam on this Mac and sign in. The iPad uses this Steam session."
  nc -z -G 2 127.0.0.1 57343 2>/dev/null && ok "Steam accepts local game connections" || bad "Steam is not accepting game connections" "Sign in to Steam and wait until the library loads."
  UDID=$(udid)
  [[ -n $UDID ]] && ok "iPad connected ($UDID)" || bad "No connected iPad" "Connect the iPad by USB (or pair it in Xcode's Devices window), unlock it and trust this Mac."
  if [[ -n $UDID ]]; then
    xcrun devicectl device info apps --device $UDID --bundle-id $BUNDLE 2>/dev/null | grep -q $BUNDLE \
      && ok "AgePad app installed" || bad "AgePad app not installed" "Run: scripts/agepad-ipad.sh build"
    printf 'ls /Documents/AgeOfEmpires2Data/resources\nexit\n' | afc | grep -q _common \
      && ok "Game files copied to the iPad" \
      || bad "Game files not on the iPad" "Copy your Mac game data (about 20 GB): see docs/IPAD-SETUP.md, step 3."
    if [[ -z \${USB_ONLY:-} ]]; then
      printf 'ls /Documents\nexit\n' | afc | grep -q AgePadSteamHost.env \
        && ok "iPad paired with this Mac (tap-to-play)" || bad "iPad not paired for tap-to-play" "Run: scripts/agepad-ipad.sh pair"
    fi
  fi
  if [[ -z \${USB_ONLY:-} ]]; then
    nc -z -G 2 127.0.0.1 $HELPER_PORT 2>/dev/null && ok "AgePad helper is running on this Mac" \
      || bad "AgePad helper is not running" "Run: scripts/agepad-ipad.sh install-helper (starts it now and at every login)"
  fi
  (( FAILED )) && { print "\nFix the items marked ✗, then run this check again."; return 1; }
  print "\nReady. Tap AgePad on the iPad to play."
}
helper_binary() { # Mac Steam path helper, built from this repository
  local BIN=$STATE/HostSteamPathRelay
  if [[ ! -x $BIN || port/de/HostSteamPathRelay.c -nt $BIN ]]; then
    mkdir -p $STATE && xcrun clang -O2 -I port/de port/de/HostSteamPathRelay.c -o $BIN || return 1
  fi
  print $BIN
}
pair() {
  UDID=$(udid); [[ -z $UDID ]] && { print "Connect the iPad by USB first."; return 1; }
  mkdir -p $STATE; chmod 700 $STATE
  [[ -s $STATE/pairing-key ]] || { openssl rand -hex 32 > $STATE/pairing-key; chmod 600 $STATE/pairing-key; }
  # Addresses the iPad tries in order: this Mac's Wi-Fi/LAN address(es), its
  # .local name, then Tailscale (if installed) for play away from home.
  local HOSTS=() IP
  for IF in en0 en1; do IP=$(ipconfig getifaddr $IF 2>/dev/null) && HOSTS+=$IP; done
  HOSTS+="$(scutil --get LocalHostName 2>/dev/null).local"
  for TS in tailscale /Applications/Tailscale.app/Contents/MacOS/Tailscale; do
    IP=$($TS ip -4 2>/dev/null | head -1) && [[ -n $IP ]] && { HOSTS+=$IP; break; }
  done
  local LIST=${(j:,:)HOSTS} FILE=$(mktemp)
  print -l "AGEPAD_STEAM_TUNNEL_HOST=$LIST" "AGEPAD_HOST_PATH_RELAY_TCP_HOST=$LIST" \
    "AGEPAD_STEAM_TUNNEL_PORT=$HELPER_PORT" "AGEPAD_HOST_PATH_RELAY_TCP_PORT=$HELPER_PORT" \
    "AGEPAD_STEAM_LOOPBACK_PORT=57343" "AGEPAD_RELAY_TOKEN=$(cat $STATE/pairing-key)" > $FILE
  printf 'put -f %s /Documents/AgePadSteamHost.env\nexit\n' $FILE | afc >/dev/null
  rm -f $FILE
  printf 'ls /Documents\nexit\n' | afc | grep -q AgePadSteamHost.env || { print "Could not write the pairing file to the iPad."; return 1; }
  print "Paired. The iPad will look for this Mac at: $LIST"
  print "Next: scripts/agepad-ipad.sh install-helper (once), then tap AgePad on the iPad."
}
serve() {
  [[ -s $STATE/pairing-key ]] || { print "Run scripts/agepad-ipad.sh pair first."; return 1; }
  local BIN=$(helper_binary) || return 1
  exec python3 scripts/agepad-helper.py --port $HELPER_PORT --token-file $STATE/pairing-key --path-relay $BIN --state-dir $STATE
}
install_helper() {
  [[ -s $STATE/pairing-key ]] || { print "Run scripts/agepad-ipad.sh pair first."; return 1; }
  local BIN=$(helper_binary) || return 1
  local PY=$(command -v python3)
  mkdir -p ${AGENT:h}
  cat > $AGENT <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>local.agepad.helper</string>
<key>ProgramArguments</key><array>
<string>$PY</string><string>$ROOT/scripts/agepad-helper.py</string>
<string>--port</string><string>$HELPER_PORT</string>
<string>--token-file</string><string>$STATE/pairing-key</string>
<string>--path-relay</string><string>$BIN</string>
<string>--state-dir</string><string>$STATE</string>
</array>
<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
<key>StandardOutPath</key><string>$STATE/helper.log</string>
<key>StandardErrorPath</key><string>$STATE/helper.log</string>
</dict></plist>
EOF
  launchctl bootout gui/$(id -u) $AGENT 2>/dev/null
  launchctl bootstrap gui/$(id -u) $AGENT && sleep 1
  nc -z -G 2 127.0.0.1 $HELPER_PORT && print "Helper running; it starts automatically at login. Log: $STATE/helper.log" \
    || { print "Helper did not start; see $STATE/helper.log"; return 1; }
}
build() {
  local UDID=$(udid); [[ -z $UDID ]] && { print "No connected iPad. Run: scripts/agepad-ipad.sh check"; return 1; }
  local PROFILE=${AGEPAD_PROFILE:?Set AGEPAD_PROFILE to a development profile for $BUNDLE with the increased-memory-limit capability (docs/IPAD-SETUP.md, step 2)}
  local IDENTITY=${AGEPAD_IDENTITY:?Set AGEPAD_IDENTITY to your Apple Development signing identity hash (security find-identity -v -p codesigning)}
  local STAMP=$(date +%Y%m%d-%H%M%S) OUT=generated/ipad-build-$(date +%Y%m%d-%H%M%S)
  print "Building the iPad compatibility layer…"
  python3 scripts/build-de-device-runtime.py --package $CANDIDATE/package $OUT/runtime || return 1
  print "Packaging and signing…"
  python3 -c "import json;c=json.load(open('scripts/ipad-launch-env.json'))['play'];skip={'AGEPAD_STEAM_TUNNEL_HOST','AGEPAD_HOST_PATH_RELAY_TCP_HOST','AGEPAD_STEAM_TUNNEL_PORT','AGEPAD_HOST_PATH_RELAY_TCP_PORT','AGEPAD_STEAM_LOOPBACK_PORT'};print('\n'.join(k+'='+v for k,v in c.items() if k not in skip))" > $OUT.launch.env
  python3 scripts/prepare-de-device-probe.py --candidate-root $CANDIDATE --boundary $OUT/runtime --ipc-load-probe $IPC \
    --launch-env $OUT.launch.env \
    --original-steam-module "$STEAM_APP/Age Of Empires II.app/Contents/Frameworks/libsteam_api.dylib" \
    --steam-app-manifest "$HOME/Library/Application Support/Steam/steamapps/appmanifest_813780.acf" \
    --output $OUT/AgePadDeviceProbe.app --profile "$PROFILE" --increased-memory-limit --identity $IDENTITY > $OUT.log 2>&1 \
    || { tail -5 $OUT.log; return 1; }
  codesign --verify --deep --strict $OUT/AgePadDeviceProbe.app || return 1
  print "Installing on the iPad (in place; saves and game files are kept)…"
  xcrun devicectl device install app --device $UDID $OUT/AgePadDeviceProbe.app | grep -E 'installationURL|rror'
}
play() {
  USB_ONLY=1 check >/dev/null || { USB_ONLY=1 check; return 1; }
  local UDID=$(udid) MINUTES=${1:-240} RUN=generated/ipad-session-$(date +%Y%m%d-%H%M%S)
  mkdir -p $RUN
  $CANDIDATE/package/HostSteamPathRelay $RUN/path.sock 20 > $RUN/host-path.log 2>&1 &
  sleep 0.5
  python3 scripts/relay-de-steam-device.py --bind :: --allow paired-tunnel --listen-port 61343 --steam-port 57343 \
    --path-listen-port 61344 --path-socket $RUN/path.sock --seconds $(( MINUTES*60 )) > $RUN/relay.log 2>&1 &
  local RELAY=$!; sleep 1.5
  # The USB relay speaks no pairing handshake; an empty key disables it even
  # when the iPad also has a Wi-Fi pairing file.
  local ENV=$(python3 -c "import json,sys;c=json.load(open('scripts/ipad-launch-env.json'));e=dict(c['play']);e.update(c['diagnostics'] if sys.argv[1]=='1' else {});e['AGEPAD_HOST_SESSION_PID']=sys.argv[2];e['AGEPAD_RELAY_TOKEN']='';print(json.dumps(e))" ${AGEPAD_DIAGNOSTICS:-0} $RELAY)
  print "Starting AgePad on the iPad. The intro and menu take about two minutes."
  print "Keep this window open and the iPad connected while you play (session limit: $MINUTES minutes)."
  xcrun devicectl device process launch --terminate-existing --console --device $UDID --environment-variables "$ENV" $BUNDLE > $RUN/console.log 2>&1
  kill $RELAY 2>/dev/null; wait 2>/dev/null
  print "Session ended. Logs: $RUN (run 'scripts/agepad-ipad.sh logs' for the game's own logs)."
}
logs() {
  UDID=$(udid); local DEST=generated/ipad-logs/$(date +%Y%m%d-%H%M%S); mkdir -p $DEST
  printf 'get -f /Library/Caches/AgePadDiagnostics/launch.log %s/launch.log\nget -f /Library/Caches/AgePadDiagnostics/watchdog.log %s/watchdog.log\nexit\n' $DEST $DEST \
    | afc >/dev/null
  ls -la $DEST
  grep -E 'DE_MEMORY_LIMIT|DE_FAULT sig' $DEST/watchdog.log 2>/dev/null | head -3
  grep DE_WATCHDOG_TICK $DEST/watchdog.log 2>/dev/null | tail -1 | cut -c1-90
}
case ${1:-check} in check) check;; build) build;; pair) pair;; serve) serve;; install-helper) install_helper;;
  play) shift; play "$@";; logs) logs;; *) sed -n 2,12p $0; exit 2;; esac
