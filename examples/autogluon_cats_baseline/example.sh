#!/usr/bin/env bash
# about: AutoGluon TabularPredictor (CPU, 60 s, host only: no TFLite/microTVM export) vs a RAM-bounded Kenning AutoML VAE on the same CATS windows; accuracy, F1 and model size side by side
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# shellcheck source-path=SCRIPTDIR source=../_lib/automl.sh
. "$(dirname "$0")/../_lib/automl.sh"
AG_SECONDS=${KENNING_EX_AG_SECONDS:-60}

build() {
  env_need automl autogluon
  # 1. the MCU-side candidate: Kenning AutoML within max32690evkit's RAM (128 KB - 85 KB application)
  automl_search "${KENNING_EX_AUTOML_MINUTES:-1.5}" max32690evkit/max32690/m4 85
  automl_eval_host "$EX_OUT/automl/automl_conf_0.yml" kenning_vae
  # 2. the same train/test windows (Kenning's split, seed 12345) for AutoGluon
  in_env automl python -I "$EX_LIB/cats_export.py" "$CATS_ROOT" "$EX_OUT/cats.npz" 2>&1 | grep -v 'I0000\|absl'
}
run() {
  build
  echo "== AutoGluon TabularPredictor, ${AG_SECONDS} s, CPU ($BOXT_JOBS threads), no torch models"
  in_env autogluon python -I "$EX_LIB/autogluon_baseline.py" "$EX_OUT/cats.npz" "$EX_OUT/autogluon" \
    --time-limit "$AG_SECONDS" --cpus "$BOXT_JOBS" --kenning "$EX_OUT/measurements_kenning_vae.json" >"$EX_OUT/autogluon.log" 2>&1 \
    || { tail -25 "$EX_OUT/autogluon.log"; return 1; }
  cat "$EX_OUT/autogluon/compare.md"
  python -I - "$EX_OUT/autogluon/compare.json" <<'PY'
import json, sys
rows = json.load(open(sys.argv[1]))
ag, kv = rows[0], rows[1]
assert ag["samples"] == kv["samples"], "different test sets"
assert ag["accuracy"] >= 0.8 and kv["accuracy"] >= 0.8, rows
print(f"   AutoGluon is {ag['model_bytes'] / kv['model_bytes']:.0f}x the Kenning TFLite model and runs on the host only")
PY
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
