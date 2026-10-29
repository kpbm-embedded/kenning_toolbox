# @NAME@: Kenning AutoML within a RAM budget

Made by `kenning-box new automl @NAME@`. The flow of ADI/Antmicro's
[automl-embedded](https://github.com/analogdevicesinc/automl-embedded) VS Code plugin, from the command line:
`kenning automl` searches VAE anomaly detectors with AutoPyTorch (SMAC3 Bayesian optimisation, Hyperband epoch
budgets) for `time_limit` minutes on the CPU; each candidate is converted to TFLite and dropped when
`application_size + model size` exceeds the board's RAM (Kenning's `platforms.yml`). `run.sh` then checks the returned
models against that budget (`build/ram_check.md`) and tests the best one on the host.

| key | here | swap for |
|---|---|---|
| `automl.time_limit` | 2 (minutes) | longer searches find better models |
| `automl.application_size` | 85 KB (rest of the firmware) | your application's RAM |
| `platform.name` | `max32690evkit/max32690/m4` (128 KB RAM) | any `platforms.yml` board, e.g. `stm32f746g_disco/stm32f746xx` |
| `dataset.csv_file` | CATS nano (2,500 windows, 18 channels) | your CSV: columns, then a label column (0 normal, >0 anomaly) |

Run: `./run.sh` (2 min search + 1 min) or `./run.sh --dry-run`. Needs `kenning-box extra install automl` (CPU torch,
about 5 GB env). Deploying the result to a simulated MCU: `kenning-box examples run automl_cats_renode`.
