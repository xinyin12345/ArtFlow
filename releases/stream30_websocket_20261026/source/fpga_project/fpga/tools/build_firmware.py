#!/usr/bin/env python3
"""Build the self-booting 12 KiB Sapphire image. No pip packages or IDE required."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GCC = Path(r"D:\soft\Efinity\efinity-riscv-ide-2026.1\toolchain\bin\riscv-none-elf-gcc.exe")
RAM_BYTES = 12288


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def extract_table() -> tuple[int, str]:
    """Ignore commented-out IMX219 example. Preserve all 164 SC431HAI writes."""
    rom = ROOT / "rtl/cam_i2c_ctrl/i2c/i2c_master_reg_rom.v"
    source = re.sub(r"/\*.*?\*/|//[^\n]*", "", rom.read_text(encoding="utf-8-sig"), flags=re.S)
    rows = re.findall(r"ROM\[8'h([\da-f]+)\]\s*=\s*\{16'h([\da-f]+),\s*8'h([\da-f]+),\s*1'b0\s*\}", source, re.I)
    if len(rows) != 164 or [int(i, 16) for i, _, _ in rows] != list(range(164)):
        raise RuntimeError("SC431HAI table must contain precisely 164 sequential write entries")
    table = "/* Generated from the preserved v04 camera ROM by tools/build_firmware.py. */\n"
    table += "#ifndef ARTFLOW_CAMERA_TABLE_H\n#define ARTFLOW_CAMERA_TABLE_H\n#include <stdint.h>\n"
    table += "#define CAMERA_REGISTER_COUNT 164u\n"
    table += "static const struct __attribute__((packed)) { uint16_t address; uint8_t value; } camera_registers[] = {\n"
    table += "".join(f"    {{ 0x{address.lower()}, 0x{value.lower()} }}, /* {int(i, 16)} */\n" for i, address, value in rows)
    table += "};\n#endif\n"
    target = ROOT / "firmware/include/camera_table.h"
    target.write_text(table, encoding="ascii", newline="\n")
    return len(rows), sha256(rom)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gcc", type=Path, default=None,
                        help="Path to riscv-none-elf-gcc (or set RISCV_GCC)")
    parser.add_argument("--out", type=Path, default=ROOT / "outputs/firmware")
    args = parser.parse_args()
    gcc = args.gcc or Path(os.environ.get("RISCV_GCC", str(DEFAULT_GCC)))
    if not gcc.is_file():
        found = shutil.which("riscv-none-elf-gcc")
        if not found:
            raise SystemExit(f"RISC-V GCC not found: {gcc}; provide --gcc")
        gcc = Path(found)
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    work = ROOT / "work/firmware"
    work.mkdir(parents=True, exist_ok=True)
    count, rom_hash = extract_table()
    elf = out / "artflow_v05.elf"
    binary = out / "artflow_v05.bin"
    mapfile = out / "artflow_v05.map"
    gcc_prefix = gcc.name.removesuffix(".exe").removesuffix("gcc")
    suffix = ".exe" if gcc.suffix.lower() == ".exe" else ""
    def tool(name: str) -> str:
        return str(gcc.with_name(gcc_prefix + name + suffix))
    sources = [ROOT / "firmware/start.S", *sorted((ROOT / "firmware/src").glob("*.c"))]
    flags = ["-march=rv32im_zicsr_zifencei", "-mabi=ilp32", "-mcmodel=medany", "-Oz", "-flto", "-g",
             "-ffreestanding", "-fno-builtin", "-fno-common", "-fno-stack-protector",
             "-fdata-sections", "-ffunction-sections", "-fstack-usage", "-msmall-data-limit=0",
             "-Wall", "-Wextra", "-Werror", "-nostdlib", "-nostartfiles",
             "-I", str(ROOT / "firmware/include")]
    log = []
    def run(argv: list[str]) -> str:
        result = subprocess.run(argv, cwd=work, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, check=False)
        log.append(result.stdout)
        if result.returncode:
            (out / "build.log").write_text("\n".join(log), encoding="utf-8")
            raise SystemExit(result.stdout)
        return result.stdout
    objects = []
    for source in sources:
        obj = work / (source.stem + ".o")
        run([str(gcc), *flags, "-c", str(source), "-o", str(obj)])
        objects.append(str(obj))
    run([str(gcc), *flags, *objects, "-T", str(ROOT / "firmware/linker.ld"),
         "-Wl,--gc-sections,--build-id=none", f"-Wl,-Map={mapfile}", "-o", str(elf)])
    run([tool("objcopy"), "-O", "binary", str(elf), str(binary)])
    size = run([tool("size"), str(elf)])
    disassembly = run([tool("objdump"), "-d", str(elf)])
    (out / "artflow_v05.dis").write_text(disassembly, encoding="utf-8")
    symbols = run([tool("nm"), "-n", str(elf)])
    (out / "artflow_v05.symbols").write_text(symbols, encoding="utf-8")
    image = binary.read_bytes()
    if len(image) > RAM_BYTES - 1024:
        raise SystemExit("Image exceeds OCRAM budget including the reserved 1 KiB stack")
    image += b"\0" * (RAM_BYTES - len(image))
    lanes = []
    ip = ROOT / "ip/sapphire_soc"
    ip.mkdir(parents=True, exist_ok=True)
    for lane in range(4):
        path = ip / f"EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol{lane}.bin"
        path.write_text("".join(f"{byte:08b}\n" for byte in image[lane::4]), encoding="ascii", newline="\n")
        lanes.append({"path": path.relative_to(ROOT).as_posix(), "sha256": sha256(path), "lines": RAM_BYTES // 4})
    # Physical split-bank images: lower 8 KiB + upper 4 KiB.
    for lane in range(4):
        base = ip / f"EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol{lane}"
        symbols = image[lane::4]
        for suffix, data in [("lo", symbols[:2048]), ("hi", symbols[2048:])]:
            Path(str(base) + "." + suffix + ".bin").write_text("".join(f"{byte:08b}\n" for byte in data), encoding="ascii")
    # Reconstruct bytes from the four files, proving bit/lane order and padding.
    recovered = bytearray(RAM_BYTES)
    for lane, record in enumerate(lanes):
        recovered[lane::4] = bytes(int(line, 2) for line in (ROOT / record["path"]).read_text().splitlines())
    if recovered != image:
        raise SystemExit("BRAM lane reconstruction failed")
    metadata = {
        "entry": "0xf9000000", "ram_bytes": RAM_BYTES, "stack_reserved_bytes": 1024,
        "isa": "rv32im_zicsr_zifencei", "core_hz": 100000000,
        "uart_base": "0xf8010000", "i2c_base": "0xf8016000", "control_base": "0xf8100000",
        "camera_register_count": count, "camera_rom_sha256": rom_hash,
        "compiler": run([str(gcc), "--version"]).splitlines()[0],
        "image_bytes": binary.stat().st_size,
        "elf_sha256": sha256(elf), "binary_sha256": sha256(binary), "lanes": lanes,
        "source_hashes": {p.relative_to(ROOT).as_posix(): sha256(p) for p in
                          [*sources, ROOT / "firmware/linker.ld", *sorted((ROOT / "firmware/include").glob("*.h"))]},
    }
    (out / "build_manifest.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    # Avoid recording the full disassembly twice in the concise build log.
    (out / "build.log").write_text(metadata["compiler"] + "\n" + size +
                                 f"PASS: {count} camera registers; 4 x 3072 byte lanes round-trip verified; physical 2048+1024 split\n", encoding="utf-8")
    print(size.strip())
    print(f"PASS: firmware built: {binary.stat().st_size} bytes; 1 KiB stack reserved; {count} camera entries")
    print(f"ELF: {elf}")


if __name__ == "__main__":
    main()
