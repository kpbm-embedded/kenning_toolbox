# @NAME@: Kenning scenario

Made by `kenning-box new scenario @NAME@`. A Kenning scenario is one JSON file with the
blocks of a deployment pipeline (see https://antmicro.github.io/kenning/json-scenarios.html):

| block | here | swap for |
|---|---|---|
| `platform` | `LocalPlatform` (this host) | `ZephyrPlatform` / `BareMetalPlatform` with a `name` from `kenning available-platforms` (needs a runtime binary + `protocol`) |
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (452 KB download) | `kenning list datasets` |
| `optimizers` | TFLite int8 | `TVMCompiler` (target `llvm`), `ONNXCompiler`, `IREECompiler` (chain them; each consumes the previous output) |
| `runtime` | `TFLiteRuntime` | `TVMRuntime`, `ONNXRuntime`, `IREERuntime` (must match the last optimizer) |
| `protocol` (optional) | - | `NetworkProtocol` (kenning server) or `UARTProtocol` (board / Renode UART) |

Run:

```sh
./run.sh                                         # or:
$BOX_KENNING/kenning-box scenario @NAME@.json    # measurements under the kenning-box build dir
$BOX_KENNING/kenning-box kenning optimize test --cfg @NAME@.json --measurements build/m.json
```

Relative paths (`./build/...`) are relative to the directory you run from (`run.sh` cds here).
Check a result: `python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`.
