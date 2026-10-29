# @NAME@: microTVM C sources for an MCU

Made by `kenning-box new microtvm_c @NAME@`. TVM target `zephyr` generates plain C operator code plus the graph/params blob that kenning-zephyr-runtime loads; nothing runs on the host, so `run.sh` only compiles the C.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | TFLite fp32 -> `TVMCompiler` target `zephyr` | Kenning's own header template (`gh://antmicro:kenning-zephyr-runtime/...`, online) |

Run:

```sh
./run.sh               # kenning optimize, then `cc -c build/model/model.c`
./run.sh --dry-run     # print the commands only
```

Use the output with [kenning-zephyr-runtime](https://github.com/antmicro/kenning-zephyr-runtime) (west + Zephyr SDK, not part of this ID).

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run microtvm_c_codegen`).
