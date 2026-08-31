#!/usr/bin/env python3
"""Generate the sprite sheets for Hoard.

The art is written as text. Each sprite is a block of characters, one per pixel,
mapped through a small shared palette — so a sprite can be edited in any text editor,
diffed like code, and regenerated deterministically. That matters more than it sounds:
it means the art is reviewable in a pull request, and a change to the palette repaints
everything at once.

No third-party modules. PNGs are written directly with zlib, so this runs anywhere
Python does.

    python3 tools/pixelart.py project/art
"""
import os, sys, zlib, struct

CELL = 32

# ---------------------------------------------------------------- palette
# Kept deliberately small. A limited palette is most of what makes pixel art read as a
# single piece of work rather than a pile of assets.
PAL = {
    ".": None,                 # transparent
    "K": (0x0d, 0x0a, 0x10),   # outline, near black
    "k": (0x1b, 0x17, 0x20),   # cave dark
    "u": (0x2a, 0x24, 0x30),   # ground, dark row
    "U": (0x33, 0x2c, 0x3b),   # ground, light row
    "S": (0x5a, 0x55, 0x60),   # stone
    "s": (0x3b, 0x33, 0x40),   # stone dark
    "G": (0xe8, 0xc0, 0x5a),   # gold
    "H": (0xf5, 0xdc, 0x9c),   # gold light
    "g": (0x8a, 0x71, 0x34),   # gold dark
    "W": (0xb9, 0x8a, 0x4e),   # wood
    "w": (0x7a, 0x58, 0x30),   # wood dark
    "R": (0xd1, 0x55, 0x3f),   # alarm red
    "r": (0x8f, 0x46, 0x34),   # deep red
    "E": (0xff, 0xff, 0xff),   # eye white
    "P": (0x1a, 0x15, 0x20),   # pupil
    "b": (0x6f, 0xa8, 0xc9),   # water
    "B": (0x1c, 0x34, 0x44),   # water dark
    # bodies — filled per sprite from a trio, see `tint`
    "1": None, "2": None, "3": None,
    # hero cloth
    "c": (0xc9, 0xce, 0xd8),
    "d": (0x8b, 0x93, 0xa2),
    "e": (0x6d, 0x6a, 0x76),
}

TINTS = {
    "chucker":   ((0x4a, 0x8f, 0x3d), (0x6f, 0xbf, 0x5b), (0x93, 0xd8, 0x80)),
    "digger":    ((0x93, 0x9e, 0x3c), (0xc9, 0xd4, 0x5f), (0xe2, 0xea, 0x92)),
    "barricade": ((0x2c, 0x63, 0x34), (0x3f, 0x8a, 0x4a), (0x5c, 0xad, 0x68)),
    "sapper":    ((0x8a, 0x63, 0x34), (0xb9, 0x8a, 0x4e), (0xd6, 0xac, 0x74)),
    "reeve":     ((0x6a, 0x31, 0x24), (0x8f, 0x46, 0x34), (0xb0, 0x60, 0x4a)),
    "hero":      ((0x8b, 0x93, 0xa2), (0xc9, 0xce, 0xd8), (0xe6, 0xea, 0xf1)),
    "sergeant":  ((0x8a, 0x62, 0x34), (0xb9, 0x8a, 0x4e), (0xd3, 0xa4, 0x68)),
    "runner":    ((0xa8, 0x99, 0x70), (0xd8, 0xc9, 0xa0), (0xee, 0xe4, 0xc6)),
}


def write_png(path, w, h, rows):
    """rows: list of h lists of (r,g,b,a) tuples."""
    # bytearray.extend rather than struct.pack per pixel — the difference is a second
    # versus several minutes once a contact sheet gets large.
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for px in row:
            raw.extend(px)
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def render(art, tint=None, scale=1):
    """Turn a block of characters into pixel rows."""
    pal = dict(PAL)
    if tint:
        pal["1"], pal["2"], pal["3"] = TINTS[tint]
    lines = [l for l in art.strip("\n").split("\n")]
    w = max(len(l) for l in lines)
    h = len(lines)
    rows = []
    for line in lines:
        row = []
        for x in range(w):
            ch = line[x] if x < len(line) else "."
            col = pal.get(ch)
            row.append((0, 0, 0, 0) if col is None else (col[0], col[1], col[2], 255))
        for _ in range(scale):
            rows.append([p for p in row for _ in range(scale)])
    return w * scale, h * scale, rows


def save(outdir, name, art, tint=None, scale=1):
    w, h, rows = render(art, tint, scale)
    path = os.path.join(outdir, name + ".png")
    write_png(path, w, h, rows)
    return name, w, h


# ---------------------------------------------------------------- primitives
# Hand-typing 32 rows of characters is fine for a plank wall and hopeless for a face.
# These draw onto a character grid instead, so a sprite is composed rather than typed,
# and `outline` then walks the whole thing once and puts a hard black edge around it —
# which is most of what makes a shape read at this size.

class Grid:
    def __init__(self, w=CELL, h=CELL):
        self.w, self.h = w, h
        self.px = [["." for _ in range(w)] for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c != ".":
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return "."

    def rect(self, x, y, w, h, c):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.set(i, j, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for j in range(int(cy - ry), int(cy + ry) + 1):
            for i in range(int(cx - rx), int(cx + rx) + 1):
                dx = (i - cx + 0.5) / max(0.5, rx)
                dy = (j - cy + 0.5) / max(0.5, ry)
                if dx * dx + dy * dy <= 1.0:
                    self.set(i, j, c)

    def tri(self, p0, p1, p2, c):
        xs = [p0[0], p1[0], p2[0]]
        ys = [p0[1], p1[1], p2[1]]
        def side(ax, ay, bx, by, px, py):
            return (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        for j in range(min(ys), max(ys) + 1):
            for i in range(min(xs), max(xs) + 1):
                d0 = side(p0[0], p0[1], p1[0], p1[1], i, j)
                d1 = side(p1[0], p1[1], p2[0], p2[1], i, j)
                d2 = side(p2[0], p2[1], p0[0], p0[1], i, j)
                if (d0 >= 0 and d1 >= 0 and d2 >= 0) or (d0 <= 0 and d1 <= 0 and d2 <= 0):
                    self.set(i, j, c)

    def line(self, x0, y0, x1, y1, c, thick=1):
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            for t in range(thick):
                self.set(x0 + t, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy; x0 += sx
            if e2 < dx:
                err += dx; y0 += sy

    def outline(self, c="K"):
        """A hard black edge around everything solid. Done once, at the end."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] != ".":
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = self.get(x + dx, y + dy)
                    if n != "." and n != c:
                        add.append((x, y))
                        break
        for x, y in add:
            self.px[y][x] = c
        return self

    def text(self):
        return "\n".join("".join(r) for r in self.px)
