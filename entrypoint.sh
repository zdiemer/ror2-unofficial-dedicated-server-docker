#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME" "$STEAM_COMPAT_DATA_PATH"
python3 /opt/prepare.py
cd /work/game
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp -ac &
export DISPLAY=:99
sleep 2
exec /opt/proton/current/proton run \
  '/work/game/Risk of Rain 2.exe' -batchmode -nographics -server --disableCrossplay \
  -logFile '/work/game/headless-player.log'
