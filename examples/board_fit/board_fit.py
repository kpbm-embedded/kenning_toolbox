"""Do compiled models fit the owned boards? Flash/RAM from Kenning's platforms.yml.

usage: python -I board_fit.py PLATFORMS.yml OUT.md MODEL.tflite [MODEL2.tflite ...]
A model fits when model size <= FLASH_SHARE of the flash and the arena upper bound (tflite_info.py)
<= RAM_SHARE of the RAM: the rest is left for the application, RTOS and the TFLM interpreter (about
20-40 KB of code). Writes a Markdown table; exits 1 when a board is missing from platforms.yml or the
expected fit results (EXPECT) do not hold.
"""
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "_lib"))
from tflite_info import info  # noqa: E402

FLASH_SHARE, RAM_SHARE = 0.5, 0.5
# owned boards -> Kenning / Zephyr platform name
BOARDS = {
    "CH32V003 (RISC-V, 16 KB / 2 KB)": "ch32v003evt/ch32v003",
    "BlackPill F411": "blackpill_f411ce/stm32f411xe",
    "WeAct G431 core": "weact_stm32g431_core/stm32g431xx",
    "WeAct H562 core": "weact_stm32h5_core/stm32h562xx",
    "WeAct MiniSTM32H743": "mini_stm32h743/stm32h743xx",
    "Raspberry Pi Pico": "rpi_pico/rp2040",
    "Raspberry Pi Pico 2 (M33)": "rpi_pico2/rp2350a/m33",
    "nRF52840 Pro Micro / nice!nano": "promicro_nrf52840/nrf52840",
    "ESP32-S3 DevKitC": "esp32s3_devkitc/esp32s3/procpu",
    "ESP32-C3 DevKitM": "esp32c3_devkitm/esp32c3",
}
# sanity checks on the result: (board, model file name part, fits?)
EXPECT = [("CH32V003 (RISC-V, 16 KB / 2 KB)", "int8", False), ("BlackPill F411", "int8", True)]


def main() -> int:
    plat_file, out = Path(sys.argv[1]), Path(sys.argv[2])
    models = [info(Path(m)) for m in sys.argv[3:]]
    plats = yaml.safe_load(plat_file.read_text())
    rows, fits, bad = [], {}, 0
    head = "| Board | Kenning platform | Flash KB | RAM KB | " + " | ".join(m["file"] for m in models) + " |"
    rows += [head, "|" + "---|" * (4 + len(models))]
    for label, name in BOARDS.items():
        p = plats.get(name)
        if not p or not p.get("flash_size_kb") or not p.get("ram_size_kb"):
            print(f"FAIL  {name}: not in platforms.yml or no flash/RAM size"); bad += 1; continue
        fl, ram = int(p["flash_size_kb"]), int(p["ram_size_kb"])
        cells = []
        for m in models:
            ok = m["size"] <= FLASH_SHARE * fl * 1024 and m["arena_upper_bound"] <= RAM_SHARE * ram * 1024
            fits[(label, m["file"])] = ok
            cells.append(f"{'fits' if ok else 'no'} ({m['size'] / 1024:.1f} KB, arena<={m['arena_upper_bound'] / 1024:.1f} KB)")
        rows.append(f"| {label} | `{name}` | {fl} | {ram} | " + " | ".join(cells) + " |")
    for board, part, want in EXPECT:
        for (b, f), ok in fits.items():
            if b == board and part in f and ok != want:
                print(f"FAIL  expected {f} {'to fit' if want else 'not to fit'} on {board}"); bad += 1
    text = (f"# Board fit ({len(BOARDS)} owned boards, model <= {FLASH_SHARE:.0%} flash, arena <= {RAM_SHARE:.0%} RAM)\n\n"
            + "\n".join(rows) + "\n")
    out.write_text(text)
    print(text)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
