# shellcheck shell=bash
# Helpers for the kenning-zephyr-runtime examples (sourced after common.sh). The runtime is built with the
# sibling 32_03_zephyr (west + Zephyr SDK, read-only) by `kenning-box kzr build`; Kenning then starts Renode
# (32_06_renode's when present) with the build's .repl + zephyr.elf and talks to the app over a simulated UART.
KB="$KENNING_BOX_ROOT/kenning-box"
RENODE_TIMEOUT=${KENNING_EX_RENODE_TIMEOUT:-900}   # seconds for one simulated run (Kenning can hang after a UART error)

kzr_need() { # exit 3 (skip) with a clear message when the Zephyr flow cannot run here
  [ -n "${KENNING_ZEPHYR_ID:-}" ] || { echo "skip: Zephyr not found (set BOX_ZEPHYR or install the sibling 32_03_zephyr)"; exit 3; }
  [ -r "$KENNING_KZR_DIR/kenning-zephyr-runtime/app/CMakeLists.txt" ] || { echo "skip: kenning-zephyr-runtime not fetched: ./kenning-box kzr setup"; exit 3; }
}

# kzr_fw <board> <runtime> <out_dir> [kzr build options...]: build the evaluation app, print its memory use
kzr_fw() {
  local board=$1 rt=$2 out=$3; shift 3
  echo "== kenning-box kzr build $board $rt (Zephyr: $KENNING_ZEPHYR_ID)"
  "$KB" kzr build "$board" "$rt" --out "$out" "$@" >"$out.log" 2>&1 || { [ -n "${KZR_QUIET:-}" ] || tail -30 "$out.log"; return 1; }
  grep -E '^ +(FLASH|RAM):' "$out.log" | sed 's/^ */   /'
  [ -s "$out/zephyr/zephyr.elf" ] && ls "$out"/*.repl >/dev/null
}

# kzr_test <cfg> <measurements.json> [optimize]: kenning [optimize] test on the simulated board (UART over a pty)
kzr_test() {
  local cfg=$1 meas=$2 steps=(test); [ "${3:-}" = optimize ] && steps=(optimize test)
  echo "== kenning ${steps[*]} --cfg $(basename "$cfg") on Renode of $(basename "${KENNING_KZR_RENODE%/install/renode}")"
  # KZR_RUN: optional prefix such as `kenning-box extra run automl` (Kenning from another pixi env)
  # shellcheck disable=SC2086  # KZR_RUN is a word list
  (cd "$EX_OUT" && timeout -k 30 "$RENODE_TIMEOUT" ${KZR_RUN:-} env PYRENODE_PATH="$KENNING_KZR_RENODE" \
      kenning "${steps[@]}" --cfg "$cfg" --measurements "$meas" --verbosity WARNING) >"${meas%.json}.log" 2>&1 \
    || { tr '\r' '\n' <"${meas%.json}.log" | grep -v 'I0000\|absl' | tail -25; return 1; }
}

# mcu_report <measurements.json>: what the simulated MCU reported (peak allocation, device-side inference time)
mcu_report() {
  python -I - "$1" <<'PY'
import json, statistics, sys
d = json.load(open(sys.argv[1]))
t = d.get("target_inference_step") or []
rt = d.get("protocol_inference_step") or []
alloc = d.get("allocation_stats") or {}
when = f"device-side median {1000 * statistics.median(t):.3f} ms, " if t else ""
print(f"   device: {len(rt)} inferences over UART, {when}inference step median {1000 * statistics.median(rt):.2f} ms (protocol_inference_step); "
      f"peak allocation {alloc.get('peak_allocated', '-')} B; model {d.get('compiled_model_size')} B")
PY
}
