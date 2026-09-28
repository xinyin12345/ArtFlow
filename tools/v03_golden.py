#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ArtFlow v03 黄金模型（纯 Python，无第三方依赖）

  gen   : 生成测试用 RAW10 Bayer 帧 + 2x2 合并后的期望 RGB（与 rtl/video/bayer_bin2x2.v 逐位一致）
  check : 把仿真抓到的 HDMI 帧（sim 输出的 hex）与期望图逐像素比对，并输出 PNG 方便肉眼看

用法（在 sim 目录下）：
  python ../tools/v03_golden.py gen   --w 1920 --h 1080 --out full
  python ../tools/v03_golden.py check --w 1920 --h 1080 --out full
生成的文件：
  <out>_raw.hex         RAW10，每行一个像素（3 位 hex），行优先
  <out>_exp_p<k>.hex    Bayer 相位 k 的期望合并结果，每行一个像素 RRGGBB，(w/2)x(h/2)
  <out>_scene.png       原始场景（未马赛克）
  <out>_exp_p0.png      期望结果（放大前）
check 读取：
  <out>_cap.hex         仿真抓到的一帧，每行一个像素 RRGGBB，w x h（HDMI 输出分辨率）
"""
import argparse
import random
import struct
import sys
import zlib

# 与 ArtFlow_top.v 里的 CFG_*_GAIN 默认值一致（仿真 TB 用同样的值）
GAINS = {"r": 0x0118, "g": 0x0100, "b": 0x015E}

# Bayer 相位：R 所在 (行, 列)
BAYER_NAMES = ["RGGB", "GRBG", "GBRG", "BGGR"]


def r_pos(phase):
    return (phase >> 1) & 1, phase & 1          # (row, col)


# ------------------------------------------------------------------ 场景
def make_scene(w, h, seed=1):
    """返回 [y][x] -> (R,G,B) 10bit 的场景，覆盖：色条、渐变、斜边、高亮饱和区、噪声"""
    rnd = random.Random(seed)
    bars = [(1023, 1023, 1023), (1023, 1023, 0), (0, 1023, 1023), (0, 1023, 0),
            (1023, 0, 1023), (1023, 0, 0), (0, 0, 1023), (0, 0, 0)]
    scene = []
    for y in range(h):
        row = []
        for x in range(w):
            if y < h // 4:                                   # 色条
                r, g, b = bars[min(7, x * 8 // w)]
            elif y < h // 2:                                 # 三色水平渐变
                v = x * 1023 // max(1, w - 1)
                band = (y - h // 4) * 3 // max(1, h // 4)
                r, g, b = [(v, 0, 0), (0, v, 0), (0, 0, v)][min(2, band)]
            elif y < 3 * h // 4:                             # 斜向条纹 + 彩色圆
                cx, cy, rad = w * 3 // 4, h * 5 // 8, max(2, h // 10)
                if (x - cx) ** 2 + (y - cy) ** 2 < rad * rad:
                    r, g, b = 900, 300, 100
                else:
                    s = 1023 if ((x + y) // 8) % 2 else 64
                    r, g, b = s, (s * 3) // 4, s // 2
            else:                                            # 随机噪声（让 Gr != Gb，测舍入和饱和）
                r, g, b = rnd.randrange(1024), rnd.randrange(1024), rnd.randrange(1024)
            row.append((r, g, b))
        scene.append(row)
    return scene


def mosaic(scene, phase, seed=2):
    """按 Bayer 相位把场景变成 RAW10；每个采样点再加一点独立噪声"""
    rnd = random.Random(seed)
    ry, rx = r_pos(phase)
    h, w = len(scene), len(scene[0])
    raw = []
    for y in range(h):
        row = []
        for x in range(w):
            r, g, b = scene[y][x]
            if (y & 1) == ry and (x & 1) == rx:
                v = r
            elif (y & 1) != ry and (x & 1) != rx:
                v = b
            else:
                v = g
            v = min(1023, max(0, v + rnd.randrange(-8, 9)))
            row.append(v)
        raw.append(row)
    return raw


# ------------------------------------------------------------------ 与 RTL 逐位一致的 2x2 合并
def bin2x2(raw, phase, gains=GAINS):
    ry, rx = r_pos(phase)
    h, w = len(raw), len(raw[0])
    out = []
    for by in range(h // 2):
        row = []
        for bx in range(w // 2):
            def px(r, c):
                return raw[2 * by + r][2 * bx + c]
            R = px(ry, rx)
            B = px(1 - ry, 1 - rx)
            GS = px(ry, 1 - rx) + px(1 - ry, rx)
            r8 = min(255, (R * gains["r"]) >> 10)
            g8 = min(255, (GS * gains["g"]) >> 11)
            b8 = min(255, (B * gains["b"]) >> 10)
            row.append((r8, g8, b8))
        out.append(row)
    return out


# ------------------------------------------------------------------ PNG（纯 Python）
def write_png(path, img):
    h, w = len(img), len(img[0])
    raw = bytearray()
    for row in img:
        raw.append(0)
        for (r, g, b) in row:
            raw += bytes((r, g, b))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 6)))
        f.write(chunk(b"IEND", b""))


def to8(scene):
    return [[(r >> 2, g >> 2, b >> 2) for (r, g, b) in row] for row in scene]


def upscale2(img):
    out = []
    for row in img:
        r2 = [p for p in row for _ in (0, 1)]
        out.append(r2)
        out.append(list(r2))
    return out


# ------------------------------------------------------------------ 命令
def cmd_gen(a):
    scene = make_scene(a.w, a.h)
    write_png(f"{a.out}_scene.png", to8(scene))
    # RAW 统一按相位 0 (RGGB) 马赛克；其它相位的期望 = 同一份 RAW 用不同相位去解
    # （RTL 只关心“怎么解”，这样 4 个相位共用一个输入文件）
    raw = mosaic(scene, 0)
    with open(f"{a.out}_raw.hex", "w") as f:
        for row in raw:
            f.write("\n".join(f"{v:03x}" for v in row))
            f.write("\n")
    for k in range(4):
        exp = bin2x2(raw, k)
        with open(f"{a.out}_exp_p{k}.hex", "w") as f:
            for row in exp:
                f.write("\n".join(f"{r:02x}{g:02x}{b:02x}" for (r, g, b) in row))
                f.write("\n")
        if k == 0:
            write_png(f"{a.out}_exp_p0.png", exp)
    print(f"gen: {a.w}x{a.h} RAW -> {a.w//2}x{a.h//2} RGB, files prefix '{a.out}_'")


def cmd_check(a):
    exp = []
    with open(f"{a.out}_exp_p{a.phase}.hex") as f:
        vals = [int(s, 16) for s in f.read().split()]
    ew, eh = a.w // 2, a.h // 2
    for y in range(eh):
        exp.append([((v >> 16) & 255, (v >> 8) & 255, v & 255) for v in vals[y * ew:(y + 1) * ew]])
    exp_up = upscale2(exp)

    with open(f"{a.out}_cap.hex") as f:
        cv = [int(s, 16) for s in f.read().split()]
    if len(cv) != a.w * a.h:
        print(f"check: FAIL  captured {len(cv)} pixels, expected {a.w*a.h}")
        return 1
    cap = [[((v >> 16) & 255, (v >> 8) & 255, v & 255) for v in cv[y * a.w:(y + 1) * a.w]]
           for y in range(a.h)]
    write_png(f"{a.out}_cap.png", cap)
    write_png(f"{a.out}_exp_up.png", exp_up)

    bad = 0
    first = None
    for y in range(a.h):
        for x in range(a.w):
            if cap[y][x] != exp_up[y][x]:
                bad += 1
                if first is None:
                    first = (x, y, cap[y][x], exp_up[y][x])
    if bad:
        x, y, c, e = first
        print(f"check: FAIL  {bad} / {a.w*a.h} pixels differ; first at ({x},{y}) got {c} exp {e}")
        diff = [[(255, 0, 0) if cap[y][x] != exp_up[y][x] else (0, 0, 0) for x in range(a.w)]
                for y in range(a.h)]
        write_png(f"{a.out}_diff.png", diff)
        return 1
    print(f"check: PASS  {a.w}x{a.h} = {a.w*a.h} pixels identical (phase {BAYER_NAMES[a.phase]})")
    return 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["gen", "check"])
    p.add_argument("--w", type=int, default=1920)
    p.add_argument("--h", type=int, default=1080)
    p.add_argument("--out", default="full")
    p.add_argument("--phase", type=int, default=0)
    a = p.parse_args()
    return cmd_gen(a) if a.cmd == "gen" else cmd_check(a)


if __name__ == "__main__":
    sys.exit(main() or 0)
