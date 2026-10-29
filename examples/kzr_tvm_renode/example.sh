#!/usr/bin/env bash
# about: microTVM on a simulated MCU: Keras -> TFLite -> TVM target zephyr (C ops + graph), built into kenning-zephyr-runtime (32_03_zephyr) for stm32f746g_disco, evaluated over UART in Renode
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/kzr.sh
. "$(dirname "$0")/../_lib/kzr.sh"

build() {
  kzr_need
  render scenario.json "$EX_OUT/scenario.json" KZR="$KENNING_KZR_DIR/kenning-zephyr-runtime"
  # 1. the operator C code is model specific: compile it on the host first (TVM 0.18, target zephyr, cortex-m7)
  echo "== kenning optimize (TFLite -> microTVM C sources)"
  (cd "$EX_OUT" && kenning optimize --cfg "$EX_OUT/scenario.json" --verbosity ERROR) >"$EX_OUT/optimize.log" 2>&1 \
    || { tail -30 "$EX_OUT/optimize.log"; return 1; }
  echo "   $(grep -c 'FUNC(tvmgen_' "$EX_OUT/model/model.h") operator functions, graph+params $(wc -c <"$EX_OUT/model/model.graph_data") B"
  # 2. firmware with exactly these operators (CONFIG_KENNING_TVM_MODEL_PRE_GEN copies model.{c,h,graph_data,...})
  kzr_fw stm32f746g_disco tvm "$EX_OUT/fw" --model "$EX_OUT/model/model.graph_data" -- -DCONFIG_KENNING_TVM_MODEL_PRE_GEN=y
}
run() {
  build
  # 3. Kenning sends the same graph+params over UART and runs the test set on the simulated board
  kzr_test "$EX_OUT/scenario.json" "$EX_OUT/measurements_mcu.json"
  summarize "$EX_OUT/measurements_mcu.json"
  mcu_report "$EX_OUT/measurements_mcu.json"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
