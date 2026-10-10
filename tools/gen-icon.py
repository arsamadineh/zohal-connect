#!/usr/bin/env python3
"""Generate the Zohal brand icon (stdlib only, no Pillow needed).

Brand mark: full-bleed square in the dark surface token (#0E0F10) with a
centered planet square outline and a horizontal ring bar, both in the light
text token (#ECEDEE). Sharp corners only. Written as a plain RGBA PNG via
zlib so CI and developers need no extra tools.

Usage: python3 tools/gen-icon.py [size] [output]
Defaults: 256 packaging/linux/zohal.png
"""

import struct
import sys
import zlib


def chunk(kind: bytes, data: bytes) -> bytes:
    out = struct.pack(">I", len(data)) + kind + data
    out += struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    return out


def save_png(path: str, size: int, pixels: bytes) -> None:
    raw = b"".join(
        b"\x00" + pixels[y * size * 4:(y + 1) * size * 4]
        for y in range(size)
    )
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)


def paint(size: int) -> bytes:
    bg = (14, 15, 16, 255)
    fg = (236, 237, 238, 255)
    ring = (165, 166, 167, 255)
    buf = bytearray(size * size * 4)
    for i in range(0, len(buf), 4):
        buf[i:i + 4] = bytes(bg)

    def px(x: int, y: int, color: tuple) -> None:
        if 0 <= x < size and 0 <= y < size:
            o = (y * size + x) * 4
            buf[o:o + 4] = bytes(color)

    # Planet: centered square outline, side = size * 5/16, stroke = size/64.
    side = size * 5 // 16
    stroke = max(2, size // 64)
    x0 = (size - side) // 2
    y0 = (size - side) // 2
    for x in range(x0, x0 + side):
        for s in range(stroke):
            px(x, y0 + s, fg)
            px(x, y0 + side - 1 - s, fg)
    for y in range(y0, y0 + side):
        for s in range(stroke):
            px(x0 + s, y, fg)
            px(x0 + side - 1 - s, y, fg)

    # Ring: horizontal bar across the full width at center, thickness stroke.
    cy = size // 2
    for x in range(size):
        for s in range(stroke):
            px(x, cy - stroke // 2 + s, ring)

    return bytes(buf)


def main() -> None:
    size = int(sys.argv[1]) if len(sys.argv) > 1 else 256
    out = sys.argv[2] if len(sys.argv) > 2 else "packaging/linux/zohal.png"
    save_png(out, size, paint(size))
    print(f"Wrote {out} ({size}x{size})")


if __name__ == "__main__":
    main()
