#!/usr/bin/env python3
"""Generate simple solid-color placeholder launcher PNGs (no Pillow needed).

Used to seed res/mipmap-* for template-app and the Forge app itself.
Forge overwrites template-app's mipmaps at runtime with the user's chosen
icon, so these only need to be valid, reasonably sized PNGs.
"""
import struct
import zlib
import os

DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def make_png(size: int, rgb=(255, 102, 0)) -> bytes:
    raw = bytearray()
    for _y in range(size):
        raw.append(0)  # filter type 0 for each scanline
        for _x in range(size):
            raw.extend(bytes(rgb))
    compressed = zlib.compress(bytes(raw), 9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)  # color type 2 = RGB
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")


def main():
    base = os.path.join(os.path.dirname(__file__), "..")
    targets = [
        (os.path.join(base, "template-app", "src", "main", "res"), (255, 140, 0)),
        (os.path.join(base, "app", "src", "main", "res"), (124, 77, 255)),
    ]
    for res_dir, color in targets:
        for density, size in DENSITIES.items():
            d = os.path.join(res_dir, f"mipmap-{density}")
            os.makedirs(d, exist_ok=True)
            png = make_png(size, color)
            for name in ("ic_launcher.png", "ic_launcher_round.png"):
                with open(os.path.join(d, name), "wb") as f:
                    f.write(png)
        print(f"Wrote launcher PNGs to {res_dir}")


if __name__ == "__main__":
    main()
