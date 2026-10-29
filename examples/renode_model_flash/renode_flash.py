"""Put a compiled model into the flash of simulated boards in Renode (pyrenode3) and read it back.

usage: python -I renode_flash.py PLATFORMS.yml MODEL.tflite
For each board: create the Renode machine from Renode's own platform file, compare Renode's flash and
RAM sizes with Kenning's platforms.yml (Renode's SoC model may be larger than the board's part: it must
not be smaller), load the model at a fixed flash offset (like a firmware's model partition) and compare
every byte read back over the system bus. Exit 1 on any mismatch.
"""
import struct
import sys
from pathlib import Path

import yaml
from pyrenode3.wrappers import Emulation, Monitor

# Kenning platform -> (Renode platform file, flash peripheral, flash base, RAM peripheral, model offset)
BOARDS = {
    "nrf52840dk/nrf52840": ("platforms/cpus/nrf52840.repl", "flash", 0x0, "ram", 0x80000),
    "stm32f746g_disco/stm32f746xx": ("platforms/cpus/stm32f746.repl", "flash", 0x08000000, "sram", 0x80000),
}


def mon(m, cmd: str) -> str:
    out, err = m.execute(cmd)
    if err:
        raise RuntimeError(f"{cmd}: {err}")
    return out.strip()


def main() -> int:
    plats = yaml.safe_load(Path(sys.argv[1]).read_text())
    model = Path(sys.argv[2]).resolve()
    blob = model.read_bytes()
    Emulation()
    m = Monitor()
    bad = 0
    for i, (name, (repl, fl, base, ram, off)) in enumerate(BOARDS.items()):
        mon(m, f'mach create "board{i}"')
        mon(m, f"machine LoadPlatformDescription @{repl}")
        fl_kb = int(mon(m, f"sysbus.{fl} Size"), 16) // 1024
        ram_kb = int(mon(m, f"sysbus.{ram} Size"), 16) // 1024
        p = plats[name]
        sizes_ok = fl_kb >= p["flash_size_kb"] and ram_kb >= p["ram_size_kb"] and off + len(blob) <= fl_kb * 1024
        addr = base + off
        mon(m, f"sysbus LoadBinary @{model} {hex(addr)}")
        words = [int(mon(m, f"sysbus ReadDoubleWord {hex(addr + j)}"), 16) for j in range(0, len(blob), 4)]
        same = struct.pack(f"<{len(words)}I", *words)[:len(blob)] == blob
        ok = sizes_ok and same
        bad += 0 if ok else 1
        print(f"{'ok  ' if ok else 'FAIL'}  {name:29s} {repl}: flash {fl_kb} KB (board {p['flash_size_kb']}), "
              f"RAM {ram_kb} KB (board {p['ram_size_kb']}); model {len(blob)} B at {hex(addr)} "
              f"read back {'identical' if same else 'DIFFERENT'}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
