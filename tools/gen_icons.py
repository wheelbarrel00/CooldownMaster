"""Writes the settings window's five sidebar icons into media/: icon-lanes, icon-ready, icon-bars,
icon-filter and icon-person. 16 px, white with the shape in alpha, like the shared library's icons, which
the window tints. The shapes are 16 x 16 drawings: 1.5 px strokes (the bars 2 px) with square ends.

Run from the repo root:  python tools/gen_icons.py
"""

import math
import os
import struct

SIZE = 16
SS = 8
MEDIA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "media")


def stroke(x, y, x0, y0, x1, y1, w):
    """Inside a square-ended stroke of width w from (x0, y0) to (x1, y1)."""
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    along = (x - x0) * ux + (y - y0) * uy
    across = abs((x - x0) * -uy + (y - y0) * ux)
    return -w / 2 <= along <= length + w / 2 and across <= w / 2


def path(x, y, points, w):
    return any(stroke(x, y, *points[i], *points[i + 1], w) for i in range(len(points) - 1))


def box(x, y, left, top, width, height):
    return left <= x <= left + width and top <= y <= top + height


def cubic(p0, p1, p2, p3, steps=24):
    out = []
    for i in range(steps + 1):
        t = i / steps
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def lanes(x, y):
    return (path(x, y, [(1.5, 8), (14.5, 8)], 1.5)
            or box(x, y, 3.2, 5.6, 4, 4.8) or box(x, y, 9.4, 5.6, 4, 4.8))


def ready(x, y):
    outline = box(x, y, 1.75, 1.75, 12.5, 12.5) and not box(x, y, 3.25, 3.25, 9.5, 9.5)
    return outline or path(x, y, [(5.2, 8.2), (7.2, 10.2), (11.0, 6.0)], 1.5)


def bars(x, y):
    return (path(x, y, [(2, 4), (14, 4)], 2) or path(x, y, [(2, 8), (10.4, 8)], 2)
            or path(x, y, [(2, 12), (6.6, 12)], 2))


FUNNEL = [(2.2, 3), (13.8, 3), (9.4, 8.4), (9.4, 12.8), (6.6, 14.2), (6.6, 8.4), (2.2, 3)]


def funnel(x, y):
    return path(x, y, FUNNEL, 1.5)


SHOULDERS = cubic((3, 14.2), (3, 11.2), (5.2, 9.2), (8, 9.2)) + cubic((8, 9.2), (10.8, 9.2), (13, 11.2), (13, 14.2))[1:]


def person(x, y):
    head = abs(math.hypot(x - 8, y - 5.4) - 2.6) <= 0.75
    return head or path(x, y, SHOULDERS, 1.5)


def render(shape):
    rows = []
    for py in range(SIZE):
        row = bytearray()
        for px in range(SIZE):
            hits = 0
            for sy in range(SS):
                for sx in range(SS):
                    if shape(px + (sx + 0.5) / SS, py + (sy + 0.5) / SS):
                        hits += 1
            row += bytes((255, 255, 255, round(255 * hits / (SS * SS))))
        rows.append(bytes(row))
    rows.reverse()
    return b"".join(rows)


def write_tga(path_, pixels):
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x08)
    with open(path_, "wb") as fh:
        fh.write(header + pixels)
    return len(header) + len(pixels)


def main():
    for name, shape in (("icon-lanes", lanes), ("icon-ready", ready), ("icon-bars", bars),
                        ("icon-filter", funnel), ("icon-person", person)):
        out = os.path.join(MEDIA, name + ".tga")
        print("wrote %s %d bytes" % (out, write_tga(out, render(shape))))


if __name__ == "__main__":
    main()
