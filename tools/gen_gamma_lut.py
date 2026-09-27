#!/usr/bin/env python3
"""
ArtFlow v02 — 生成 gamma_lut.v 用的 256x8 查找表（每行 2 位十六进制）

用法：
  # 1) 从旧的 1024x10 曲线转换（与 v01 gamma_correction.v 逐位等价）
  python tools/gen_gamma_lut.py --from-mem rtl/gamma_conrrection/2P2.mem \
         -o rtl/gamma_conrrection/gamma_2p2_8b.mem

  # 2) 按公式生成：out = 255 * (in/255) ** exp
  #    exp = 2.2       -> 变暗（与 2P2.mem 同方向）
  #    exp = 1/2.2     -> 标准 sRGB 编码方向（线性 RAW 数据提亮）
  python tools/gen_gamma_lut.py --exp 0.4545 -o rtl/gamma_conrrection/gamma_inv2p2_8b.mem

旧模块 8bit 模式的取表方式：r_gamma[{d, d[7:6]}][9:2]
即 10bit 地址 = d*4 + d>>6，取出 10bit 值后丢掉低 2 位。
"""
import argparse


def from_mem10(path):
    vals = [int(t, 16) for t in open(path).read().split()]
    if len(vals) != 1024:
        raise SystemExit(f"{path}: 期望 1024 项，实际 {len(vals)} 项")
    return [(vals[(d << 2) | (d >> 6)] >> 2) & 0xFF for d in range(256)]


def from_exp(exp):
    return [min(255, int(round(255.0 * (d / 255.0) ** exp))) for d in range(256)]


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--from-mem", help="旧 1024x10 曲线文件")
    g.add_argument("--exp", type=float, help="幂指数")
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()

    lut = from_mem10(a.from_mem) if a.from_mem else from_exp(a.exp)
    assert len(lut) == 256 and all(0 <= v <= 255 for v in lut)
    with open(a.out, "w", newline="\n") as f:
        f.write("\n".join(f"{v:02X}" for v in lut) + "\n")
    print(f"wrote {a.out}: lut[0]={lut[0]:02X} lut[128]={lut[128]:02X} lut[255]={lut[255]:02X}")


if __name__ == "__main__":
    main()
