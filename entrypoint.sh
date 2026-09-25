#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME"
python3 /opt/prepare.py
cd /work/game
exec xvfb-run -a -s '-screen 0 1024x768x24' /opt/proton/current/proton run \
  '/work/game/Risk of Rain 2.exe' -batchmode -nographics -server --disableCrossplay \
  -logFile '/work/game/headless-player.log'
