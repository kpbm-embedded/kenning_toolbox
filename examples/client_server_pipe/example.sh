#!/usr/bin/env bash
# about: target-device flow over named pipes: `kenning server` (PipeProtocol) + client; the same message protocol a board speaks over UART
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# Kenning's UARTProtocol is client-only (the server side is the board's firmware), so on the host the
# protocol path is shown with PipeProtocol: the client uploads the model and the I/O spec, the server
# runs every inference and returns results and statistics.
build() {
  PIPE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kenning-pipe.XXXXXX")
  render scenario.json "$EX_OUT/scenario.json" PIPE="$PIPE_DIR/kpipe"
  echo "scenario: $EX_OUT/scenario.json (pipes in $PIPE_DIR)"
}
run() {
  build
  trap 'kill "${srv:-}" 2>/dev/null || true; rm -rf "$PIPE_DIR"' EXIT   # own temp dir with the two FIFOs
  echo "== kenning server (PipeProtocol)"
  (cd "$EX_OUT" && exec timeout 600 kenning server --cfg "$EX_OUT/scenario.json" --verbosity INFO) >"$EX_OUT/server.log" 2>&1 &
  srv=$!
  local _ rc=0
  for _ in $(seq 1 120); do
    grep -q 'Server started' "$EX_OUT/server.log" 2>/dev/null && break
    kill -0 "$srv" 2>/dev/null || { tail -20 "$EX_OUT/server.log"; return 1; }
    sleep 1
  done
  PYTHONPATH="$EX_DIR/../client_server_tflite/client_patch${PYTHONPATH:+:$PYTHONPATH}" KENNING_EX_REMOTE_LOCAL=1 \
    scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_pipe.json" || rc=1
  kill "$srv" 2>/dev/null || true; wait "$srv" 2>/dev/null || true
  [ "$rc" = 0 ] || { tail -20 "$EX_OUT/server.log"; return 1; }
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_pipe.json"
  grep -q 'Client connected' "$EX_OUT/server.log" || { echo "server saw no client"; return 1; }
  [ -s "$EX_OUT/server_model.tflite" ] || { echo "model was not uploaded to the server"; return 1; }
  echo "pipe server: client connected, int8 model uploaded ($(wc -c <"$EX_OUT/server_model.tflite") B), inference served remotely"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
