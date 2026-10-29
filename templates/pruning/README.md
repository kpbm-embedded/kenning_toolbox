# @NAME@: pruning + int8

Made by `kenning-box new pruning @NAME@`. Keras magnitude pruning (TF Model Optimization) to the target sparsity, short fine-tuning, then TFLite int8.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `optimizers` | `TensorFlowPruningOptimizer` (50 %, 3 epochs) -> TFLite int8 (int8 I/O) | `target_sparsity`, `prune_dense`, `epochs` |
| `runtime` | `TFLiteRuntime` | - |

Run:

```sh
./run.sh               # optimize + test, measurements in build/
./run.sh --dry-run     # print the commands only
```

Pruned weights are stored densely: the gain shows after compression (gzip) or with sparse kernels.

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run tflite_pruning`).
