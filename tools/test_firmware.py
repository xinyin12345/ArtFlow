#!/usr/bin/env python3
"""Compile and run native tests with a mocked MMIO boundary, using the real C code."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", default=os.environ.get("HOST_CC", "gcc"))
    args = parser.parse_args()
    cc = shutil.which(args.cc) or args.cc
    work = ROOT / "work/firmware/tests"
    work.mkdir(parents=True, exist_ok=True)
    out = ROOT / "outputs/firmware"
    out.mkdir(parents=True, exist_ok=True)
    cases = {"console": ["console.c"], "i2c": ["i2c.c"],
             "camera": ["camera.c"], "commands": ["console.c"]}
    results = []
    for case, sources in cases.items():
        executable = work / (case + (".exe" if os.name == "nt" else ""))
        files = [ROOT / "firmware/tests" / f"test_{case}.c",
                 *(ROOT / "firmware/src" / source for source in sources)]
        command = [cc, "-std=c11", "-O2", "-Wall", "-Wextra", "-Werror", "-DARTFLOW_HOST_TEST",
                   "-I", str(ROOT / "firmware/include"), *(str(p) for p in files), "-o", str(executable)]
        built = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if built.returncode:
            print(built.stdout); raise SystemExit(built.returncode)
        # MSYS native GCC may depend on DLLs beside its executable.
        env = os.environ.copy()
        if Path(cc).is_file(): env["PATH"] = str(Path(cc).parent) + os.pathsep + env.get("PATH", "")
        result = subprocess.run([str(executable)], text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=10, env=env)
        print(result.stdout.strip())
        results.append({"test": case, "passed": result.returncode == 0, "output": result.stdout.strip()})
        if result.returncode:
            raise SystemExit(result.returncode)
    # Independent equivalence check against v04 when baseline exists.
    baseline = ROOT.parent / "v04/rtl/cam_i2c_ctrl/i2c/i2c_master_reg_rom.v"
    current = ROOT / "rtl/cam_i2c_ctrl/i2c/i2c_master_reg_rom.v"
    if baseline.is_file():
        if hashlib.sha256(baseline.read_bytes()).digest() != hashlib.sha256(current.read_bytes()).digest():
            raise SystemExit("Preserved camera ROM differs from v04")
        results.append({"test": "v04_camera_rom", "passed": True, "output": "SHA256 equal to preserved v04 ROM"})
        print("PASS camera ROM: SHA256 equal to v04")
    (out / "host_tests.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    source_files = [p for p in (ROOT / "firmware").rglob("*")
                    if p.is_file() and p.suffix.lower() in {".c", ".h", ".s", ".ld"}]
    source_files.append(Path(__file__).resolve())
    fingerprint = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted(source_files)}
    (out / "host_test_source_sha256.json").write_text(
        json.dumps(fingerprint, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {len(results)} firmware test groups")


if __name__ == "__main__":
    main()
