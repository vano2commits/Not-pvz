#!/usr/bin/env python3
"""Render every sprite into project/art/.

    python3 tools/build_art.py

Sprites are authored at 32px per cell and drawn in-game at 3x, so the board keeps the
96px cells every balance number was swept against while the art stays pixel-perfect —
3 is an integer, so nothing is ever resampled.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelart as pa
import sprites as sp

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "project", "art")

JOBS = [
    ("goblin_chucker",   sp.chucker,   "chucker"),
    ("goblin_digger",    sp.digger,    "digger"),
    ("goblin_barricade", sp.barricade, "barricade"),
    ("goblin_sapper",    sp.sapper,    "sapper"),
    ("hero_squire",      sp.squire,    "hero"),
    ("hero_scout",       sp.scout,     "hero"),
    ("hero_sergeant",    sp.sergeant,  "sergeant"),
    ("hero_runner",      sp.runner,    "runner"),
    ("hero_leaper",      sp.scout,     "hero"),
    ("hero_pavise",      sp.squire,    "sergeant"),
    ("hero_reeve",       sp.reeve,     "reeve"),
    ("tile_ground_a",    lambda: sp.ground(False), None),
    ("tile_ground_b",    lambda: sp.ground(True),  None),
    ("tile_rubble",      sp.rubble,    None),
    ("tile_collapsed",   sp.collapsed, None),
    ("tile_cracking",    sp.cracking,  None),
    ("tile_water",       sp.water,     None),
    ("prop_coin",        sp.coin,      None),
    ("prop_rock",        sp.rock,      None),
    ("prop_hoard",       sp.hoard,     None),
]
for i in range(5):
    JOBS.append(("tile_vein_%d" % i, (lambda n: (lambda: sp.vein(n)))(i), None))


def main():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for name, fn, tint in JOBS:
        grid = fn()
        made.append(pa.save(OUT, name, grid.text(), tint))
    for name, w, h in made:
        print("%-20s %dx%d" % (name, w, h))
    print("%d sprites -> %s" % (len(made), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
