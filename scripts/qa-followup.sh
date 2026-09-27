#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/qa-device.py build
python3 scripts/device.py install build/qa-roku.zip
python3 scripts/qa-acceptance.py
python3 scripts/qa-extra.py --resume
python3 scripts/qa-caption-faults.py --resume
python3 scripts/qa-buffer.py --resume
cp build/qa-results.json build/qa-combined-results.json
python3 scripts/qa-preferences.py
python3 scripts/qa-watchlist.py
python3 scripts/qa-recents.py
python3 scripts/qa-sources.py
python3 scripts/qa-timing.py
python3 scripts/qa-caption-size.py
python3 scripts/qa-countdown.py
python3 scripts/qa-diagnostics.py
