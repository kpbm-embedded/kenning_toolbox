#!/usr/bin/env bash
# about: target-device flow over a protocol: `kenning server` (TFLite runtime) + client on 127.0.0.1 TCP
# The same client/server split drives a real board (UARTProtocol) or Renode; here both run on the host.
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
PORT=${KENNING_EX_PORT:-$((20000 + $$ % 10000))}

build() { render scenario.json "$EX_OUT/scenario.json" PORT="$PORT"; echo "scenario: $EX_OUT/scenario.json (port $PORT)"; }
run() {
  build
  echo "== kenning server on 127.0.0.1:$PORT"
  (cd "$EX_OUT" && exec timeout 600 kenning server --cfg "$EX_OUT/scenario.json" --verbosity INFO) >"$EX_OUT/server.log" 2>&1 &
  local srv=$! rc=0
  # wait for "Server started" (TensorFlow import takes a few seconds). Do not probe the port:
  # the server takes the first connection as its client.
  local _
  for _ in $(seq 1 120); do
    grep -q 'Server started' "$EX_OUT/server.log" 2>/dev/null && break
    kill -0 "$srv" 2>/dev/null || { tail -20 "$EX_OUT/server.log"; return 1; }
    sleep 1
  done
  # client: LocalPlatform + protocol, i.e. inference requests go to the server (client_patch/sitecustomize.py)
  PYTHONPATH="$EX_DIR/client_patch${PYTHONPATH:+:$PYTHONPATH}" KENNING_EX_REMOTE_LOCAL=1 \
    scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_client_server.json" || rc=1
  kill "$srv" 2>/dev/null || true; wait "$srv" 2>/dev/null || true
  [ "$rc" = 0 ] || { tail -20 "$EX_OUT/server.log"; return 1; }
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_client_server.json"
  grep -q 'Connected client' "$EX_OUT/server.log" || { echo "server saw no client"; return 1; }
  [ -s "$EX_OUT/server_model.tflite" ] || { echo "model was not uploaded to the server"; return 1; }
  echo "server: client connected, model uploaded ($(wc -c <"$EX_OUT/server_model.tflite") bytes), inference served remotely"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
