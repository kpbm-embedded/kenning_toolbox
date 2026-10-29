# @NAME@: Zephyr board simulated in Renode

Made by `kenning-box new zephyr_renode @NAME@`. `run.sh` builds the
[kenning-zephyr-runtime](https://github.com/antmicro/kenning-zephyr-runtime) evaluation app (TFLite Micro) for the
board with the Zephyr of `32_03_zephyr` (`kenning-box kzr build`), then `kenning optimize test` starts Renode with the
build's `.repl` + `zephyr.elf`, uploads the model over a simulated UART and runs the test set on the simulated MCU.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `platform.name` | `stm32f746g_disco` (also the west board; kzr has a UART overlay for it) | a board with an overlay in kzr `app/boards/` (`nrf52840dk/nrf52840`, `b_u585i_iot02a`, ...) |
| `optimizers` | TFLite fp32 (fits the default op resolver) | other TFLite ops: `kenning-box kzr build <board> tflite --model your.tflite` |

Run:

```sh
./run.sh               # kzr build (about 40 s) + optimize + test in Renode (about 1 min)
./run.sh --dry-run     # print the commands only
```

Needs `kenning-box kzr setup` once and `32_03_zephyr` (`BOX_ZEPHYR`); exit 3 without it. Renode: `32_06_renode`'s
when present, else kenning-box's own (both 1.17.0). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json` (example: `kzr_tflite_renode`).
