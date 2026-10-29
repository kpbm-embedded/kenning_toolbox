#!/usr/bin/env bash
# about: bring your own model: ModelInserter benchmarks an already compiled .tflite (default: one made here) without converting it
# usage: example.sh build | run | test   (via ./kenning-box examples ...)
# shellcheck source-path=SCRIPTDIR source=../_lib/common.sh
. "$(dirname "$0")/../_lib/common.sh"
# KENNING_EX_MODEL=/path/to/model.tflite benchmarks your own file (it must take the magic-wand input,
# 1x128x3x1, and give 4 classes; for another model change model_wrapper and dataset in scenario.json).
build() {
  local src=${KENNING_EX_MODEL:-}
  if [ -z "$src" ]; then
    # make a model the way an external tool would: plain TensorFlow, outside Kenning
    src="$EX_OUT/external_int8.tflite"
    python -I - "$KENNING_CACHE_DIR/models/classification/magic_wand.h5" "$DATASET" "$src" <<'PY'
import sys, numpy as np, tensorflow as tf
from pathlib import Path
from kenning.datasets.magic_wand_dataset import MagicWandDataset
m = tf.keras.models.load_model(sys.argv[1], compile=False)
d = MagicWandDataset(Path(sys.argv[2]), download_dataset=False)
x = np.array(d.dataX[:: max(1, len(d.dataX) // 100)], dtype=np.float32).reshape((-1, *m.input_shape[1:]))   # ~100 calibration windows
c = tf.lite.TFLiteConverter.from_keras_model(m)
c.optimizations = [tf.lite.Optimize.DEFAULT]
c.representative_dataset = lambda: ([s[None, ...]] for s in x)
c.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
c.inference_input_type = c.inference_output_type = tf.int8
open(sys.argv[3], "wb").write(c.convert())
print("external model:", sys.argv[3])
PY
  fi
  # Kenning reads the I/O description (names, shapes, dtypes, int8 scale/zero point) from <model>.json;
  # write it from the .tflite itself when the model came without one
  [ -r "$src.json" ] || python -I - "$src" <<'PY'
import json, sys
from ai_edge_litert.interpreter import Interpreter
it = Interpreter(model_path=sys.argv[1])
classes = ["wing", "ring", "slope", "negative"]          # magic-wand classes (model wrapper order)
def spec(d, extra):
    s = {"name": d["name"], "shape": [int(x) for x in d["shape"]], "dtype": d["dtype"].__name__, "order": 0, **extra}
    scale, zp = d["quantization"]
    if scale:
        s.update(scale=float(scale), zero_point=int(zp), prequantized_dtype="float32")
    return s
io = {"input": [{"name": "input_1", "shape": [[1, 128, 3], [1, 128, 3, 1]], "dtype": "float32"}],
      "processed_input": [spec(it.get_input_details()[0], {})],
      "output": [spec(it.get_output_details()[0], {"class_names": classes})],
      "processed_output": [{"name": "out_layer", "shape": [1, 4], "dtype": "float32", "class_names": classes}]}
json.dump(io, open(sys.argv[1] + ".json", "w"))
print("I/O spec:", sys.argv[1] + ".json")
PY
  render scenario.json "$EX_OUT/scenario.json" MODEL="$src"
  echo "scenario: $EX_OUT/scenario.json (model $src)"
}
run() {
  build
  scenario "$EX_OUT/scenario.json" "$EX_OUT/measurements_inserted.json"
  summarize --out "$EX_OUT/summary.json" "$EX_OUT/measurements_inserted.json"
  cmp "$(sed -n 's/.*"input_model_path": "\([^"]*\)".*/\1/p' "$EX_OUT/scenario.json")" "$EX_OUT/inserted.tflite" \
    && echo "benchmarked file is byte-identical to the input (no re-conversion)"
}
case "${1:-run}" in build) build ;; run|test) run ;; *) echo "usage: $0 build|run|test" >&2; exit 2 ;; esac
