#!/usr/bin/env bash
# about: kenning-zephyr-runtime (TFLite Micro) built with 32_03_zephyr for stm32f746g_disco, magic-wand scenario run by Kenning over a simulated UART in Renode (no board)
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/kzr.sh
. "$(dirname "$0")/../_lib/kzr.sh"

build() {
  kzr_need
  render scenario.json "$EX_OUT/scenario.json"
  # app/tflite.conf; op resolver from kzr's default list (Conv2D, FullyConnected, MaxPool2D, Reshape, Softmax)
  kzr_fw stm32f746g_disco tflite "$EX_OUT/fw"
}
run() {
  build
  kzr_test "$EX_OUT/scenario.json" "$EX_OUT/measurements_mcu.json" optimize
  summarize "$EX_OUT/measurements_mcu.json"
  mcu_report "$EX_OUT/measurements_mcu.json"
  python -I -c 'import json,sys; d=json.load(open(sys.argv[1])); p=d["build_cfg"]["protocol"]; assert p["type"].endswith("UARTProtocol"), p; print("   protocol:", p["type"].rsplit(".",1)[-1], p["parameters"]["baudrate"], "baud on a Renode pty")' "$EX_OUT/measurements_mcu.json"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
