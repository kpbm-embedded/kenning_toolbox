# @NAME@: TFLite fp32 baseline

Made by `kenning-box new tflite_fp32 @NAME@`. The reference pipeline: the Keras model converted to TFLite without quantization.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | TFLite `default` (fp32) | `int8`, `float16` targets |
| `runtime` | `TFLiteRuntime` (LiteRT) | - |

Run:

```sh
./run.sh               # optimize + test, measurements in build/
./run.sh --dry-run     # print the commands only
```

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run magic_wand_tflite`).
