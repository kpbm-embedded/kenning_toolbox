# @NAME@: bring your own compiled model

Made by `kenning-box new model_inserter @NAME@`. `ModelInserter` takes an already compiled model and skips conversion: benchmark a `.tflite` made by another tool (Edge Impulse, a colleague, TFLM's examples).

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | `ModelInserter` (`./model.tflite`) | `model_framework` `onnx`, `tvm`, `iree` with the matching runtime |
| `runtime` | `TFLiteRuntime` | must match the model format |

Run:

```sh
./run.sh               # uses ./model.tflite (created from `make_demo_model.json` when missing)
./run.sh --dry-run     # print the commands only
```

Kenning needs `model.tflite.json` (input/output names, shapes, dtypes, int8 scale and zero point) next to the model; the `model_inserter` example shows how to write it from the `.tflite`.

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run model_inserter`).
