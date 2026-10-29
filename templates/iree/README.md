# @NAME@: IREE

Made by `kenning-box new iree @NAME@`. Keras via ONNX to an IREE VM module (`.vmfb`), run by the IREE runtime's `local-task` driver.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | `IREECompiler` backend `llvm-cpu` | `vmvx` (portable interpreter, what MCU runtimes use) |
| `runtime` | `IREERuntime` (`local-task`) | `local-sync` |

Run:

```sh
./run.sh               # optimize + test, measurements in build/
./run.sh --dry-run     # print the commands only
```

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run magic_wand_iree`).
