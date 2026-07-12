"""Generate CooldownMaster's bundled LSM textures.

Writes uncompressed 32-bit BGRA TGAs into media/. The art is white with the shape
carried entirely in the alpha channel, because every consumer recolors it
(SetVertexColor / SetBackdropColor / SetStatusBarColor).

Run from the repo root:  python tools/gen_textures.py
"""

import os
import struct

MEDIA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "media")


def write_tga(path, width, height, rows):
    """rows[y][x] = alpha (0-255), y = 0 at the TOP. TGA stores bottom-up."""
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,          # id length
        0,          # no color map
        2,          # uncompressed true-color
        0, 0, 0,    # color map spec
        0, 0,       # x/y origin
        width, height,
        32,         # bits per pixel
        0x08,       # 8 alpha bits, bottom-left origin
    )
    body = bytearray()
    for y in range(height - 1, -1, -1):
        row = rows[y]
        for x in range(width):
            a = max(0, min(255, int(round(row[x]))))
            body += bytes((255, 255, 255, a))
    with open(path, "wb") as f:
        f.write(header)
        f.write(bytes(body))
    print(f"  {os.path.basename(path):28s} {width}x{height}  {18 + width * height * 4} bytes")


def gradient(width=256, height=32):
    """Soft vertical falloff - brightest down the middle, easing off at both edges."""
    mid = (height - 1) / 2.0
    rows = []
    for y in range(height):
        t = abs(y - mid) / mid
        a = 255.0 * (1.0 - 0.35 * (t ** 1.6))
        rows.append([a] * width)
    return width, height, rows


def glass(width=256, height=32):
    """A glossy bar - bright highlight band near the top, stepping down to a darker lower half."""
    rows = []
    for y in range(height):
        if y <= 1:
            a = 200.0
        elif y <= 3:
            a = 255.0
        elif y <= 15:
            t = (y - 4) / 11.0
            a = 235.0 + (195.0 - 235.0) * t
        else:
            t = (y - 16) / 15.0
            a = 150.0 + (118.0 - 150.0) * t
        rows.append([a] * width)
    return width, height, rows


def soft_border(cell=16):
    """Eight cells in backdrop edgeFile order: left, right, top, bottom, TL, TR, BL, BR.

    Each cell fades from transparent on its OUTER side to opaque on its INNER side, so the
    border reads as a soft shadow rather than a hard line.
    """
    width, height = cell * 8, cell

    def ramp(t):
        return 255.0 * (max(0.0, min(1.0, t)) ** 1.5)

    rows = [[0.0] * width for _ in range(height)]
    for y in range(height):
        for x in range(cell):
            fx = (x + 0.5) / cell           # 0 at left edge, 1 at right edge
            fy = (y + 0.5) / cell           # 0 at top edge, 1 at bottom edge
            inner_x, inner_y = ramp(fx), ramp(1.0 - fx)
            down, up = ramp(fy), ramp(1.0 - fy)

            rows[y][0 * cell + x] = inner_x                  # left edge: opaque toward the right
            rows[y][1 * cell + x] = inner_y                  # right edge: opaque toward the left
            rows[y][2 * cell + x] = down                     # top edge: opaque toward the bottom
            rows[y][3 * cell + x] = up                       # bottom edge: opaque toward the top
            rows[y][4 * cell + x] = inner_x * down / 255.0   # top-left corner
            rows[y][5 * cell + x] = inner_y * down / 255.0   # top-right corner
            rows[y][6 * cell + x] = inner_x * up / 255.0     # bottom-left corner
            rows[y][7 * cell + x] = inner_y * up / 255.0     # bottom-right corner
    return width, height, rows


def main():
    os.makedirs(MEDIA, exist_ok=True)
    print("Writing CooldownMaster textures to media/")
    for name, builder in (
        ("statusbar-gradient.tga", gradient),
        ("statusbar-glass.tga", glass),
        ("border-soft.tga", soft_border),
    ):
        w, h, rows = builder()
        write_tga(os.path.join(MEDIA, name), w, h, rows)


if __name__ == "__main__":
    main()
