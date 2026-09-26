#!/bin/zsh
# Mac stage of docs/STEAM-ENGINE-LOOP.md: Valve's engine from an isolated
# folder, QR sign-in, then DE's own libsteam_api attaches to it.
# Mac Steam is quit for the test and always reopened. Its folder is write-protected.
set -u
cd "$(dirname "$0")/../generated/steam-engine" || exit 1
MODE=${1:-signin}   # signin | cached | offline
STEAM_API="$HOME/Library/Application Support/Steam/steamapps/common/AoE2DE/Age Of Empires II.app/Contents/Frameworks/libsteam_api.dylib"
trap 'open -a Steam' EXIT
osascript -e 'quit app "Steam"' 2>/dev/null
for i in {1..20}; do pgrep -q steam_osx || break; sleep 1; done
typeset -a extra
case $MODE in
  signin) extra=(STAGE0_SIGNIN=$PWD/signin.html) ;;
  cached) extra=(STAGE0_STEAMID=${AGEPAD_STEAMID:?set AGEPAD_STEAMID}) ;;
  offline) extra=(STAGE0_STEAMID=${AGEPAD_STEAMID:?set AGEPAD_STEAMID} STAGE0_OFFLINE=1) ;;
esac
PROFILE=protect.sb
[[ $MODE == offline ]] && PROFILE=protect-offline.sb
(sleep 4; [[ -f signin.html && $MODE == signin ]] && open signin.html) &
sandbox-exec -f $PROFILE env HOME=$PWD/home STAGE0_GAME="$STEAM_API" $extra ./Stage0Engine $PWD/root/steamclient.dylib ${SECONDS_TO_RUN:-40} 2>&1 |
  grep --line-buffered -E 'SIGNIN|ENGINE_LOGON|ENGINE_STATE|IPCSERVER|S_API|GAME_' | tee $MODE-run.log
