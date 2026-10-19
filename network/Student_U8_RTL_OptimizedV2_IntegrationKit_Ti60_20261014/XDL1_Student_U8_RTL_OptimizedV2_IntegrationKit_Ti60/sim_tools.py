"""Locate an existing Icarus installation; no automatic installation/download."""
from pathlib import Path
import os,shutil
def iverilog_bin(root):
    candidates=[root.parent.parent/'xfeat/.fpga_tools/iverilog/bin']
    if os.environ.get('IVERILOG_BIN'):candidates.append(Path(os.environ['IVERILOG_BIN']))
    candidates += [root/'tools/iverilog/app/bin',root.parent/'style_s8_rtl_verify/tools/iverilog/app/bin']
    exe=shutil.which('iverilog.exe')
    if exe:candidates.append(Path(exe).parent)
    for p in candidates:
        if (p/'iverilog.exe').exists() and (p/'vvp.exe').exists():return p
    raise RuntimeError('Set IVERILOG_BIN to the directory containing iverilog.exe and vvp.exe')
