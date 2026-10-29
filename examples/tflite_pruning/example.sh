#!/usr/bin/env bash
# about: Keras magnitude pruning (TF Model Optimization, 50 % sparsity, 3 epochs) -> TFLite int8; zeros and gzip size vs plain int8
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
SPARSITY=${KENNING_EX_SPARSITY:-0.5}

build() {
  render scenario.json "$EX_OUT/scenario.json" SPARSITY="$SPARSITY"
  render baseline.json "$EX_OUT/baseline.json"
  echo "scenarios: $EX_OUT/scenario.json (pruned), $EX_OUT/baseline.json"
}
run() {
  build
  scenario "$EX_OUT/baseline.json" "$EX_OUT/measurements_baseline.json"
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_pruned.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_baseline.json" "$EX_OUT/measurements_pruned.json"
  tflite_info info "$EX_OUT/baseline_int8.tflite" "$EX_OUT/pruned_int8.tflite"
  tflite_info weights "$EX_OUT/pruned_int8.tflite" | tee "$EX_OUT/weights.txt"
  # pruning keeps the file size (dense storage) but the zeros compress: check sparsity and gzip size
  python -I - "$EX_OUT" "$SPARSITY" <<'PY'
import sys
out, want = sys.argv[1], float(sys.argv[2])
rows = [l.split() for l in open(f"{out}/weights.txt")]
zeros = [float(r[-2].split("=")[1]) for r in rows]
assert zeros and min(zeros) >= want - 0.05, f"weight sparsity {zeros} below {want}"
print(f"sparsity per weight tensor: {zeros} (target {want})")
PY
  local gb gp
  gb=$(tflite_info json "$EX_OUT/baseline_int8.tflite" | python -I -c 'import json,sys; print(json.load(sys.stdin)["gzip_size"])')
  gp=$(tflite_info json "$EX_OUT/pruned_int8.tflite" | python -I -c 'import json,sys; print(json.load(sys.stdin)["gzip_size"])')
  echo "gzip size: baseline $gb B, pruned $gp B"
  [ "$gp" -lt "$gb" ] || { echo "pruned model does not compress better"; return 1; }
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
