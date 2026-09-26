#!/bin/zsh
# AgePad on a physical iPad, run from the Mac that owns the Steam copy.
#   scripts/agepad-ipad.sh check            what is ready and what is missing
#   scripts/agepad-ipad.sh build            build, sign and install the app (in place, keeps saves)
#   scripts/agepad-ipad.sh sync             copy the game files to the iPad over USB-C (after a game update: only what changed)
#   scripts/agepad-ipad.sh pair             once, over USB: let the iPad reach this Mac's Steam over Wi-Fi
#   scripts/agepad-ipad.sh install-helper   run the Mac helper automatically at login (tap-to-play)
#   scripts/agepad-ipad.sh serve            run the Mac helper in this window instead
#   scripts/agepad-ipad.sh play [minutes]   engineering: start the game from the Mac over USB
#   scripts/agepad-ipad.sh logs             copy the last session's logs to generated/ipad-logs/
# Settings (environment): AGEPAD_UDID, AGEPAD_CANDIDATE (Simulator candidate root),
# AGEPAD_IPC (IPC build), AGEPAD_PROFILE, AGEPAD_IDENTITY, AGEPAD_DIAGNOSTICS=1.
set -u
ROOT=${0:A:h:h}; cd $ROOT
BUNDLE=${AGEPAD_BUNDLE_ID:-local.agepad.device-de-probe}
STEAM_APP="$HOME/Library/Application Support/Steam/steamapps/common/AoE2DE"
CANDIDATE=${AGEPAD_CANDIDATE:-generated/de-candidate-20260924-responder}
IPC=${AGEPAD_IPC:-}
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
# The game version AgePad's program was made from, and the Mac's current one.
built_version() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['stages']['steam']['bundle_version'])" $CANDIDATE/bootstrap.json 2>/dev/null; }
mac_version() { defaults read "$STEAM_APP/Age Of Empires II.app/Contents/Info.plist" CFBundleVersion 2>/dev/null; }
version_note() { # prints why the Mac's game and AgePad differ, if they do
  local MAC=$(mac_version) BUILT=$(built_version)
  [[ -n $MAC && -n $BUILT && $MAC != $BUILT ]] || return 1
  print "Steam has updated Age of Empires II on this Mac (version $MAC), but AgePad is made for version $BUILT."
  print "AgePad needs an update for the new game version before its files can be copied; until then the iPad keeps"
  print "playing the version it has (offline and single player; online matches need the current version)."
}
sync_tool() {
  local TOOL=generated/tools/agepad-sync
  if [[ ! -x $TOOL || scripts/agepad-sync.c -nt $TOOL ]]; then
    mkdir -p $TOOL:h
    cc -O2 scripts/agepad-sync.c $(pkg-config --cflags --libs libimobiledevice-1.0 libplist-2.0 2>/dev/null) -o $TOOL 2>/dev/null \
      || { print -u2 "Could not build the copy tool. Install its library with: brew install libimobiledevice"; return 1; }
  fi
  print $TOOL
}
sync() {
  UDID=$(udid); [[ -z $UDID ]] && { print "Connect the iPad to this Mac with a USB-C cable, unlock it and tap Trust."; return 1; }
  [[ -d "$STEAM_APP/AgeOfEmpires2Data" ]] || { print "Age of Empires II: DE is not installed in Steam on this Mac."; return 1; }
  local ACF="$HOME/Library/Application Support/Steam/steamapps/appmanifest_813780.acf"
  local STATE_FLAGS=$(awk -F'"' '/"StateFlags"/{print $4}' "$ACF") BUILDID=$(awk -F'"' '/"buildid"/{print $4}' "$ACF")
  [[ $STATE_FLAGS == 4 ]] || { print "Steam is still downloading or updating the game on this Mac. Let it finish, then run this again."; return 1; }
  version_note && return 1
  local TOOL; TOOL=$(sync_tool) || return 1
  $TOOL $UDID $BUNDLE "$STEAM_APP/AgeOfEmpires2Data" --build $BUILDID "$@"
}
afc() { # afcclient without hanging when the device stops answering
  local out=$(mktemp); ( afcclient -u $UDID --container $BUNDLE > $out 2>&1 ) & local pid=$!
  for i in {1..20}; do kill -0 $pid 2>/dev/null || break; sleep 0.5; done; kill $pid 2>/dev/null; cat $out; rm -f $out
}
todo() { print -P "  %F{yellow}○%f $1"; }
info() { print "  · $1"; }
# SETUP=1: missing app/game files are what setup does next, not failures.
# USB_ONLY=1 (engineering 'play'): the Mac's Steam must be running.
check() {
  FAILED=0; print "AgePad setup check"
  xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1 && ok "Xcode with iPad support" \
    || bad "Xcode not found" "Install Xcode from the App Store, open it once and let it finish installing components."
  pkg-config --exists libimobiledevice-1.0 2>/dev/null && ok "USB copy library (libimobiledevice)" \
    || bad "USB copy library missing" "Install Homebrew (https://brew.sh), then run: brew install libimobiledevice"
  [[ -d "$STEAM_APP/AgeOfEmpires2Data" ]] && ok "Your Steam copy of AoE II: DE (Mac edition) found" \
    || bad "AoE II: DE not found in Steam on this Mac" "Install Age of Empires II: Definitive Edition in Steam for Mac (you must own it)."
  if NOTE=$(version_note); then bad "Game version differs from AgePad's" "$NOTE"; fi
  [[ -f $CANDIDATE/candidate.app/DEOriginalGame ]] && ok "AgePad build package" \
    || bad "AgePad build package missing ($CANDIDATE)" "Make it once from your game: python3 scripts/bootstrap-de-simulator.py $CANDIDATE (docs/DE-BOOTSTRAP-20260919.md)"
  UDID=$(udid)
  [[ -n $UDID ]] && ok "iPad connected ($UDID)" \
    || bad "No iPad connected" "Connect the iPad with a USB-C cable, unlock it and tap Trust. First time: turn on Settings > Privacy & Security > Developer Mode."
  if [[ -n $UDID ]]; then
    local SIGNING; SIGNING=$(python3 scripts/find-signing.py $BUNDLE $UDID 2>&1) && ok "Signing set up for this iPad" \
      || bad "Signing not set up" "$SIGNING"
    if xcrun devicectl device info apps --device $UDID --bundle-id $BUNDLE 2>/dev/null | grep -q $BUNDLE; then ok "AgePad installed on the iPad"
    elif (( ${SETUP:-0} )); then todo "AgePad not installed yet (setup installs it)"
    else bad "AgePad not installed" "Run: scripts/agepad-ipad.sh setup"; fi
    local DATA=$(printf 'ls /Documents/AgeOfEmpires2Data\nexit\n' | afc)
    if [[ $DATA == *.agepad-import-inventory-checked* ]]; then ok "Game files on the iPad"
    elif (( ${SETUP:-0} )); then todo "Game files not copied yet (setup copies them, about 20 GB)"
    else bad "Game files missing or incomplete on the iPad" "Run: scripts/agepad-ipad.sh sync (about 20 GB the first time; keep 25 GB free)"; fi
  fi
  if (( ${USB_ONLY:-0} )); then
    pgrep -q steam_osx && ok "Steam is running on this Mac" || bad "Steam is not running" "Open Steam on this Mac and sign in."
    nc -z -G 2 127.0.0.1 57343 2>/dev/null && ok "Steam accepts local game connections" || bad "Steam is not accepting game connections" "Sign in to Steam and wait until the library loads."
  elif (( ! ${SETUP:-0} )); then
    print "Optional: playing through this Mac's Steam instead of Steam inside AgePad"
    [[ -n $UDID ]] && printf 'ls /Documents\nexit\n' | afc | grep -q AgePadSteamHost.env && info "iPad paired with this Mac" || info "Not paired (scripts/agepad-ipad.sh pair)"
    nc -z -G 2 127.0.0.1 $HELPER_PORT 2>/dev/null && info "Mac helper running" || info "Mac helper not running (scripts/agepad-ipad.sh install-helper)"
  fi
  (( FAILED )) && { print "\nFix the items marked ✗, then run this again."; return 1; }
  (( ${SETUP:-0} )) || print "\nReady. Open AgePad on the iPad (sign in to Steam the first time), then just tap it to play."
}
setup() {
  print "AgePad setup: builds AgePad from your own Steam copy and installs it on the iPad over USB-C.\n"
  SETUP=1 check || return 1
  print "\n1/2 Building and installing AgePad (about 2 minutes)…"
  build || return 1
  print "\n2/2 Copying the game files (the first time about 20 GB; later only what changed)…"
  sync || return 1
  print "\nDone. On the iPad: open AgePad and sign in to Steam once by scanning the QR code with the Steam app on your"
  print "phone (or use your password). After that, tap AgePad to play, online or offline."
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
steam_client() { # Valve's Steam engine for the app: the Mac's current Steam, converted once per Steam version
  local PACKAGED=$CANDIDATE/package/game-client MAC="$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents"
  [[ -f "$MAC/MacOS/steamclient.dylib" ]] || { print -u2 "Steam for Mac not found; using the Steam engine from the build package."; print $PACKAGED; return; }
  local SLICE=$(mktemp); lipo "$MAC/MacOS/steamclient.dylib" -thin arm64 -output $SLICE 2>/dev/null || cp "$MAC/MacOS/steamclient.dylib" $SLICE
  local NOW=$(shasum -a 256 $SLICE | cut -c1-12); rm -f $SLICE
  [[ $(shasum -a 256 $PACKAGED/original-steamclient.dylib | cut -c1-12) == $NOW ]] && { print $PACKAGED; return; }
  local DIR=generated/steam-client-$NOW
  if [[ ! -f $DIR/steamclient.dylib ]]; then
    print -u2 "Steam on this Mac has updated; converting its engine for the iPad (once per Steam version)…"
    rm -rf $DIR.partial
    python3 scripts/build-de-steam-client-boundary.py "$MAC" $CANDIDATE/artifacts/steam-client-audit.json \
      $CANDIDATE/artifacts/public-constants.json $DIR.partial --survey $CANDIDATE/artifacts/steam-client-survey.json \
      > generated/steam-client-$NOW.log 2>&1 || { print -u2 "Converting Steam failed (generated/steam-client-$NOW.log)."; return 1; }
    cp $PACKAGED/DEBoundary_*.dylib $DIR.partial/ && mv $DIR.partial $DIR
  fi
  print $DIR
}
  local UDID=$(udid); [[ -z $UDID ]] && { print "No connected iPad. Run: scripts/agepad-ipad.sh check"; return 1; }
  local PROFILE=${AGEPAD_PROFILE:-} IDENTITY=${AGEPAD_IDENTITY:-} FOUND
  if [[ -z $PROFILE || -z $IDENTITY ]]; then # the profile Xcode downloaded for this app and iPad
    FOUND=$(python3 scripts/find-signing.py $BUNDLE $UDID) || return 1
    PROFILE=${FOUND%%$'\n'*} IDENTITY=${FOUND##*$'\n'}
  fi
  local STAMP=$(date +%Y%m%d-%H%M%S) OUT=generated/ipad-build-$(date +%Y%m%d-%H%M%S)
  local CLIENT; CLIENT=$(steam_client) || return 1
  version_note && print "Building anyway: this refreshes Steam inside AgePad; the game itself stays at the version above."
  print "Building the iPad compatibility layer…"
  python3 scripts/build-de-device-runtime.py --package $CANDIDATE/package --steam-client $CLIENT $OUT/runtime || return 1
  if [[ -z $IPC ]]; then # Steam's IPC helper: from the Mac's current Steam, in step with the engine
    local IPCSRC=$CANDIDATE/package/ipc-helper-relay/ipcserver.arm64
    local MACIPC="$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS/ipcserver"
    mkdir -p $OUT
    [[ -f $MACIPC ]] && { lipo "$MACIPC" -thin arm64 -output $OUT/ipcserver.arm64 2>/dev/null || cp "$MACIPC" $OUT/ipcserver.arm64; IPCSRC=$OUT/ipcserver.arm64; }
    python3 scripts/build-de-device-ipc-probe.py --source $IPCSRC --output $OUT/ipc > $OUT/ipc.log 2>&1 || { tail -5 $OUT/ipc.log; return 1; }
    IPC=$OUT/ipc
  fi
  print "Packaging and signing…"
  python3 -c "import json;c=json.load(open('scripts/ipad-launch-env.json'))['play'];skip={'AGEPAD_STEAM_TUNNEL_HOST','AGEPAD_HOST_PATH_RELAY_TCP_HOST','AGEPAD_STEAM_TUNNEL_PORT','AGEPAD_HOST_PATH_RELAY_TCP_PORT','AGEPAD_STEAM_LOOPBACK_PORT'};print('\n'.join(k+'='+v for k,v in c.items() if k not in skip))" > $OUT.launch.env
  python3 scripts/prepare-de-device-probe.py --candidate-root $CANDIDATE --steam-client $CLIENT --boundary $OUT/runtime --ipc-load-probe $IPC \
    --launch-env $OUT.launch.env \
    --original-steam-module "$STEAM_APP/Age Of Empires II.app/Contents/Frameworks/libsteam_api.dylib" \
    --steam-app-manifest "$HOME/Library/Application Support/Steam/steamapps/appmanifest_813780.acf" \
    --output $OUT/AgePadDeviceProbe.app --profile "$PROFILE" --increased-memory-limit --identity $IDENTITY \
    --bundle-id $BUNDLE > $OUT.log 2>&1 \
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
case ${1:-check} in check) check;; setup) setup;; build) build;; sync) shift; sync "$@";; pair) pair;; serve) serve;; install-helper) install_helper;;
  play) shift; play "$@";; logs) logs;; *) sed -n 2,12p $0; exit 2;; esac
