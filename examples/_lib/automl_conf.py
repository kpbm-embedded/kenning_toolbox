"""Kenning AutoML results: RAM-budget check of the returned models, and scenarios derived from them.

usage: python -I automl_conf.py check <results_dir> <platforms.yml> <board> <application_kb> [--md F]
       python -I automl_conf.py derive <automl_conf_N.yml> <out.yml> <compiled.tflite> [--zephyr-build D --board B]
check: every model Kenning's AutoML returned (automl_conf_*.yml) must have an optimized size within
       RAM(board) - application_size; prints the search statistics (how many were rejected as too large).
derive: drops the automl/platform blocks of an AutoML result so `kenning optimize test` evaluates the model on the
       host (TFLite runtime), or on a simulated Zephyr board when --zephyr-build is given (kenning-zephyr-runtime).
"""
import argparse
import json
import re
import sys
from pathlib import Path

import yaml


class _Loader(yaml.SafeLoader):
    """Safe loader that keeps `!!python/name:` tags (AutoML writes class objects) as plain strings."""


_Loader.add_multi_constructor("tag:yaml.org,2002:python/name:", lambda loader, suffix, node: suffix)


def load(p: Path) -> dict:
    return yaml.load(p.read_text(), Loader=_Loader)


def check(a) -> int:
    stats = json.loads((a.results / "automl_statistics.json").read_text())
    ram = yaml.safe_load(Path(a.platforms).read_text())[a.board]["ram_size_kb"]
    budget = ram - a.application_kb
    info = stats["general_info"]
    rows, bad = [], 0
    for conf in sorted(a.results.glob("automl_conf_*.yml")):
        c = load(conf)
        mid = re.match(r"\d+_(\d+)_", Path(c["model_wrapper"]["parameters"]["model_path"]).name).group(1)
        p = stats["model_params"][mid]
        size = p["Optimized model size [KB]"]
        ok = size is not None and size <= budget
        bad += not ok
        val = stats.get("trained_model_metrics", {}).get(mid, {})
        f1 = (val.get("train") or {}).get("f1")
        rows.append(f"| {conf.name} | {mid} | {p['Total parameters']} | {size:.1f} | {budget:.0f} | "
                    f"{'-' if f1 is None else round(f1, 3)} | {'ok' if ok else 'OVER BUDGET'} |")
    head = [f"Board {a.board}: RAM {ram} KB - application {a.application_kb:g} KB = model budget {budget:g} KB",
            ", ".join(f"{k.replace('The number of ', '')}: {v}" for k, v in info.items() if k.startswith("The number")),
            "rejected by the RAM check: " + (", ".join(f"model {k} ({v['Optimized model size [KB]']:.1f} KB)" for k, v in
                                               sorted(stats["model_params"].items(), key=lambda kv: int(kv[0]))
                                               if (v.get("Optimized model size [KB]") or 0) > budget) or "none"),
            "", "| result | model | parameters | optimized size KB | budget KB | F1 (train) | check |",
            "|---|---|---|---|---|---|---|"]
    text = "\n".join(head + rows) + "\n"
    print(text, end="")
    if a.md:
        Path(a.md).write_text(text)
    if not rows:
        print("no model returned by the AutoML search", file=sys.stderr)
        return 1
    return 1 if bad else 0


def derive(a) -> int:
    c = load(a.conf)
    for k in ("automl", "platform", "runtime_builder"):
        c.pop(k, None)
    c["optimizers"][-1]["parameters"]["compiled_model_path"] = str(a.tflite)
    c["model_wrapper"]["parameters"]["model_path"] = str(Path(c["model_wrapper"]["parameters"]["model_path"]).resolve())
    if a.zephyr_build:
        c["platform"] = {"type": "ZephyrPlatform", "parameters": {
            "name": a.board, "simulated": True, "disable_profiler": True, "zephyr_build_path": str(a.zephyr_build)}}
    a.out.write_text(yaml.safe_dump(c, sort_keys=False))
    print(f"{a.out.name}: {c['model_wrapper']['type'].rsplit('.', 1)[-1]} "
          f"{Path(c['model_wrapper']['parameters']['model_path']).name} -> "
          f"{'ZephyrPlatform ' + a.board if a.zephyr_build else 'host (TFLite runtime)'}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("results", type=Path)
    c.add_argument("platforms")
    c.add_argument("board")
    c.add_argument("application_kb", type=float)
    c.add_argument("--md")
    d = sub.add_parser("derive")
    d.add_argument("conf", type=Path)
    d.add_argument("out", type=Path)
    d.add_argument("tflite", type=Path)
    d.add_argument("--zephyr-build", type=Path)
    d.add_argument("--board", default="stm32f746g_disco")
    a = ap.parse_args()
    return check(a) if a.cmd == "check" else derive(a)


if __name__ == "__main__":
    raise SystemExit(main())
