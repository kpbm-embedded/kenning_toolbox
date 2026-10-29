# @NAME@: client/server over TCP

Made by `kenning-box new client_server @NAME@`. The target-device split: `kenning server` runs the runtime (here on this PC; on a Linux board or SBC in real use), the client compiles, uploads the model and measures round trips.

| block | here | swap for |
|---|---|---|
| `model_wrapper` | magic-wand gesture CNN (46 KB .h5) | any `kenning list modelwrappers` class |
| `dataset` | MagicWandDataset (linked from kenning-box, else 452 KB download) | `kenning list datasets` |
| `protocol` | `NetworkProtocol` 127.0.0.1:12345 | the board's IP; `UARTProtocol` (`port`, `baudrate`) for MCU firmware |
| `runtime` | `TFLiteRuntime` (on the server) | the runtime the device has |

Run:

```sh
./run.sh               # server in the background, client, then the server is stopped
./run.sh --dry-run     # print the commands only
```

On a board: copy this folder and kenning-box there, run `kenning-box kenning server --cfg @NAME@.json` on the board and set `host`.

Relative paths (`./build/...`) are relative to this folder (`run.sh` cds here). Result check:
`python -I $BOX_KENNING/examples/_lib/summarize.py build/@NAME@_measurements.json`
(the matching example: `kenning-box examples run client_server_tflite`).
