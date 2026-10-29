# @NAME@: TFLite -> Apache TVM

Made by `kenning-box new tvm @NAME@`. Keras to TFLite, then TVM 0.18 compiles a native library for this CPU.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | TFLite fp32 -> `TVMCompiler` (`llvm`, `opt_level` 3) | `"target": "llvm -mcpu=native"`, `opt_level` 0-3, `use_tvm_vm` |
| `runtime` | `TVMRuntime` | `runtime_use_vm: true` with `use_tvm_vm` |

Run:

```sh
./run.sh               # optimize + test, measurements in build/
./run.sh --dry-run     # print the commands only
```

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run tvm_executors`).
