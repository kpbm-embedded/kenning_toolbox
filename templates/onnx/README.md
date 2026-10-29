# @NAME@: ONNX + ONNX Runtime

Made by `kenning-box new onnx @NAME@`. Keras to ONNX (tf2onnx), run by ONNX Runtime's CPU provider.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | `ONNXCompiler` | chain `TVMCompiler` or `IREECompiler` after it |
| `runtime` | `ONNXRuntime` (CPU) | other execution providers |

Run:

```sh
./run.sh               # optimize + test, measurements in build/
./run.sh --dry-run     # print the commands only
```

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run magic_wand_onnx`).
