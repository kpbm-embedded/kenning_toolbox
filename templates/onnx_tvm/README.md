# @NAME@: ONNX -> Apache TVM chain

Made by `kenning-box new onnx_tvm @NAME@`. Two optimizers in a row: each consumes the previous one's output (here ONNX, then TVM's ONNX frontend).

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | `ONNXCompiler` -> `TVMCompiler` (`llvm`) | any chain whose types match (`kenning list optimizers`) |
| `runtime` | `TVMRuntime` | must match the last optimizer |

Run:

```sh
./run.sh               # optimize + test, measurements in build/
./run.sh --dry-run     # print the commands only
```

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run onnx_to_tvm`).
