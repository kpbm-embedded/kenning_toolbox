#!/bin/sh
# Run the @NAME@ client/server scenario: `kenning server` in the background + client over TCP 127.0.0.1.
# KENNING_BOX = the 32_07_kenning folder (default: $BOX_KENNING from box_env.sh).
set -eu
here=$(cd "$(dirname "$0")" && pwd -P)
kb=${KENNING_BOX:-${BOX_KENNING:?set BOX_KENNING or KENNING_BOX to the 32_07_kenning folder}}
dry=""; [ "${1:-}" = --dry-run ] && dry=--dry-run
cd "$here"
mkdir -p build
# use kenning-box's copy of the dataset (offline) when this folder has none
ds="$("$kb/kenning-box" where | sed -n 's/^build  *//p')/datasets/MagicWandDataset"
[ -e build/MagicWandDataset ] || [ ! -d "$ds" ] || ln -s "$ds" build/MagicWandDataset
if [ -n "$dry" ]; then
  echo "+ kenning server --cfg $here/@NAME@.json &"
  echo "+ kenning optimize test --cfg $here/@NAME@.json --measurements $here/build/@NAME@_measurements.json (client)"
  exit 0
fi
"$kb/kenning-box" kenning server --cfg "$here/@NAME@.json" >build/server.log 2>&1 &
srv=$!
trap 'kill "$srv" 2>/dev/null || true' EXIT
i=0
until grep -q 'Server started' build/server.log 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 120 ] || ! kill -0 "$srv" 2>/dev/null; then tail -20 build/server.log; exit 1; fi
  sleep 1
done
# Kenning's LocalPlatform ignores "protocol" (upstream); the client_patch from the example switches it on
"$kb/kenning-box" run env PYTHONPATH="$kb/examples/client_server_tflite/client_patch" KENNING_EX_REMOTE_LOCAL=1 \
  kenning optimize test --cfg "$here/@NAME@.json" --measurements "$here/build/@NAME@_measurements.json"
grep -q 'Connected client' build/server.log && echo "server log: build/server.log (client connected)"
