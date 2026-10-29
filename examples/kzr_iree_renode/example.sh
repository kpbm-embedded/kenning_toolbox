#!/usr/bin/env bash
# about: IREE on a simulated MCU: Keras -> IREE 3.11 vmvx bytecode, uploaded over UART to kenning-zephyr-runtime (IREE runtime, 32_03_zephyr) on b_u585i_iot02a (Cortex-M33) in Renode
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/kzr.sh
. "$(dirname "$0")/../_lib/kzr.sh"
# b_u585i_iot02a (768 KB RAM) as in kzr's own IREE scenarios: on stm32f746g_disco the IREE app needs its heap cut
# to fit 320 KB and then its UART protocol state is lost (PROTOCOL_STATUS_UNINIT), see NOTES.md 2026-10-29.

build() {
  kzr_need
  render scenario.json "$EX_OUT/scenario.json"
  kzr_fw b_u585i_iot02a iree_vmvx "$EX_OUT/fw"   # app/iree_vmvx.conf: VMVX loader, 160 KB IREE heap, 60 KB model buffer
}
run() {
  build
  kzr_test "$EX_OUT/scenario.json" "$EX_OUT/measurements_mcu.json" optimize
  summarize "$EX_OUT/measurements_mcu.json"
  mcu_report "$EX_OUT/measurements_mcu.json"
  python -I -c 'import sys, zipfile; z = zipfile.ZipFile(sys.argv[1]); print("   vmfb:", ", ".join(n for n in z.namelist())[:120])' "$EX_OUT/magic_wand_vmvx.vmfb" || true
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
