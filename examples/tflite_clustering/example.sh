#!/usr/bin/env bash
# about: weight clustering (TF Model Optimization, 16 centroids + fine-tuning) -> TFLite; each weight tensor keeps at most 16 values
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
CLUSTERS=${KENNING_EX_CLUSTERS:-16}

build() { render scenario.json "$EX_OUT/scenario.json" CLUSTERS="$CLUSTERS"; echo "scenario: $EX_OUT/scenario.json"; }
run() {
  build
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_clustered.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_clustered.json"
  tflite_info info "$EX_OUT/clustered.tflite"
  tflite_info weights "$EX_OUT/clustered.tflite" | tee "$EX_OUT/weights.txt"
  local max
  max=$(sed -n 's/.*unique=\([0-9]*\).*/\1/p' "$EX_OUT/weights.txt" | sort -n | tail -1)
  [ -n "$max" ] && [ "$max" -le "$CLUSTERS" ] || { echo "a weight tensor has $max distinct values (> $CLUSTERS)"; return 1; }
  echo "clustering ok: at most $max distinct values per weight tensor (gzip shrinks it; see tflite_info above)"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
