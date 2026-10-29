# shellcheck shell=bash
# Helpers for the AutoML / AutoGluon examples (sourced after common.sh). Kenning AutoML needs the optional
# `automl` pixi env (torch CPU, AutoPyTorch, SMAC3), AutoGluon the `autogluon` env: ./kenning-box extra install <env>.
KB="$KENNING_BOX_ROOT/kenning-box"
CATS_ROOT="$BOXT_BUILD/datasets/CATS"

env_need() { # env...: exit 3 (skip) when an optional env is not installed
  local e; for e in "$@"; do
    [ -x "$KENNING_BOX_ROOT/.pixi/envs/$e/bin/python" ] || { echo "skip: optional env $e not installed: ./kenning-box extra install $e"; exit 3; }
  done
}
in_env() { local e=$1; shift; "$KB" extra run "$e" "$@"; }

# automl_search <minutes> <board> <application_kb>: AutoML into $EX_OUT/automl, then the RAM-budget check
automl_search() {
  local min=$1 board=$2 app=$3
  render "$EX_LIB/automl_cats.yml" "$EX_OUT/automl.yml" MIN="$min" BOARD="$board" APP_KB="$app" RES="$EX_OUT/automl" CATS="$CATS_ROOT"
  echo "== kenning automl: AutoPyTorch (SMAC + Hyperband) over the VAE, $min min, CPU, budget RAM($board) - $app KB"
  (cd "$EX_OUT" && in_env automl timeout -k 30 $(( ${min%.*} * 60 + 960 )) kenning automl --cfg "$EX_OUT/automl.yml" --verbosity INFO) \
    >"$EX_OUT/automl.log" 2>&1 || { grep -v 'I0000\|absl' "$EX_OUT/automl.log" | tail -25; return 1; }
  python -I "$EX_LIB/automl_conf.py" check "$EX_OUT/automl" "$PLATFORMS_YML" "$board" "$app" --md "$EX_OUT/ram_check.md"
}

# automl_eval_host <conf.yml> <name>: the AutoML model -> TFLite, tested on the host (TFLite runtime)
automl_eval_host() {
  local conf=$1 name=$2
  python -I "$EX_LIB/automl_conf.py" derive "$conf" "$EX_OUT/$name.yml" "$EX_OUT/$name.tflite"
  (cd "$EX_OUT" && in_env automl kenning optimize test --cfg "$EX_OUT/$name.yml" --measurements "$EX_OUT/measurements_$name.json" \
     --verbosity WARNING) >"$EX_OUT/measurements_$name.log" 2>&1 || { grep -v 'I0000\|absl' "$EX_OUT/measurements_$name.log" | tail -25; return 1; }
}

# f1 <measurements.json>...: accuracy and F1 of the anomaly class from Kenning's confusion matrix
f1() {
  python -I - "$@" <<'PY'
import json, sys
for f in sys.argv[1:]:
    (tn, fp), (fn, tp) = json.load(open(f))["eval_confusion_matrix"]
    p = tp / (tp + fp) if tp + fp else 0.0; r = tp / (tp + fn) if tp + fn else 0.0
    print(f"   {f.rsplit('/', 1)[-1]}: accuracy {(tn + tp) / (tn + fp + fn + tp):.3f}, F1(anomaly) {2 * p * r / (p + r) if p + r else 0.0:.3f} "
          f"(precision {p:.3f}, recall {r:.3f}, {int(tn + fp + fn + tp)} windows)")
PY
}
