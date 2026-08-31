"""The sprites, composed from primitives.

Silhouette is doing the work. In the prototype the heroes measured 0.79-0.81 outline
overlap when they differed only by colour and scale, which is another way of saying they
all looked the same. Everything here has something in its outline that nothing else has:
a goblin has ears, a Squire a round shield, a Scout a plume twice its head's height, a
Sergeant square pauldrons, a Runner a bare head with hair streaming back.
"""
import pixelart as pa
from pixelart import Grid

CELL = 32


def _goblin_base(g, cx=16, cy=15):
    """Head, ears, eyes, fangs. The ears are the whole identity — the first pass of this
    art had none and every unit read as a potato."""
    # Ears first, so the head overlaps their roots. They have to clear the head by a
    # good margin or they read as a lumpy skull rather than as ears — the first pass had
    # them tucked inside the silhouette and every unit looked like a potato.
    g.tri((cx - 15, cy - 9), (cx - 4, cy - 4), (cx - 6, cy + 4), "1")
    g.tri((cx + 15, cy - 9), (cx + 4, cy - 4), (cx + 6, cy + 4), "1")
    g.tri((cx - 12, cy - 7), (cx - 5, cy - 3), (cx - 6, cy + 1), "2")
    g.tri((cx + 12, cy - 7), (cx + 5, cy - 3), (cx + 6, cy + 1), "2")
    # head
    g.ellipse(cx, cy, 8, 8, "1")
    g.ellipse(cx, cy, 7, 7, "2")
    g.ellipse(cx - 2, cy - 3, 4, 3, "3")          # a light on the brow
    # eyes
    for ex in (cx - 4, cx + 3):
        g.rect(ex - 1, cy - 1, 3, 4, "E")
        g.rect(ex, cy + 1, 2, 2, "P")
    # mouth and two fangs
    g.rect(cx - 3, cy + 5, 7, 1, "K")
    g.rect(cx - 2, cy + 6, 1, 1, "E")
    g.rect(cx + 2, cy + 6, 1, 1, "E")
    return g


def chucker():
    g = Grid(CELL, CELL)
    _goblin_base(g)
    g.ellipse(27, 20, 3, 3, "S")                  # the rock, cocked back
    g.rect(22, 18, 4, 2, "1")                     # arm to it
    g.outline()
    return g


def digger():
    g = Grid(CELL, CELL)
    # a pick over the shoulder: haft up the back, head across the top
    g.line(9, 29, 22, 7, "w", 2)
    g.rect(14, 4, 14, 3, "S")
    g.tri((14, 4), (14, 10), (19, 7), "S")
    g.tri((28, 4), (28, 10), (23, 7), "S")
    _goblin_base(g)
    g.outline()
    return g


def barricade():
    g = Grid(CELL, CELL)
    _goblin_base(g, 16, 11)
    # planks, widest at the bottom, so it reads as a wall from any distance
    for i, y in enumerate((19, 23, 27)):
        w = 30 - i * 4
        x = (CELL - w) // 2
        g.rect(x, y, w, 3, "W")
        g.rect(x, y + 1, w, 1, "w")
    g.outline()
    return g


def sapper():
    g = Grid(CELL, CELL)
    g.line(24, 26, 27, 8, "w", 2)                 # shovel, held upright
    g.ellipse(27, 7, 3, 4, "S")
    _goblin_base(g)
    g.rect(7, 4, 18, 3, "G")                      # a lamp-brimmed helmet
    g.rect(9, 2, 14, 2, "G")
    g.rect(10, 2, 12, 1, "H")
    g.outline()
    return g


# ---------------------------------------------------------------- heroes

def _hero_base(g, cx=16, cy=17, narrow=1.0):
    body_w = int(6 * narrow)
    g.tri((cx - body_w - 2, cy + 12), (cx - body_w, cy - 2), (cx + body_w, cy - 2), "2")
    g.tri((cx - body_w - 2, cy + 12), (cx + body_w, cy - 2), (cx + body_w + 2, cy + 12), "2")
    g.rect(cx - body_w - 2, cy + 6, (body_w + 2) * 2, 6, "2")
    g.ellipse(cx, cy - 5, 6, 6, "2")              # helm
    g.rect(cx - 5, cy - 5, 10, 2, "K")            # visor slit
    g.rect(cx - 4, cy + 12, 3, 4, "1")            # legs
    g.rect(cx + 1, cy + 12, 3, 4, "1")
    return g


def squire():
    g = Grid(CELL, CELL)
    _hero_base(g)
    g.ellipse(7, 20, 5, 5, "e")                   # round shield on the near arm
    g.ellipse(7, 20, 2, 2, "1")
    g.outline()
    return g


def scout():
    g = Grid(CELL, CELL)
    _hero_base(g, narrow=0.72)
    g.line(17, 10, 26, 2, "R", 2)                 # a plume twice the head's height
    g.ellipse(27, 2, 3, 2, "R")
    g.outline()
    return g


def sergeant():
    g = Grid(CELL, CELL)
    _hero_base(g)
    # Pauldrons: a flat shelf across the shoulders, so the top of the shape is square
    # where every other hero's is round. Narrow enough to be armour rather than arms.
    g.rect(6, 12, 20, 4, "e")
    g.rect(7, 11, 18, 2, "d")
    g.rect(8, 11, 16, 1, "c")
    g.outline()
    return g


def runner():
    g = Grid(CELL, CELL)
    _hero_base(g, narrow=0.74)
    # No helm. Hair streams back off a bare head — kept low and blunt, because at head
    # height and pointed it reads as a beak.
    g.rect(11, 9, 11, 2, "k")
    g.rect(19, 12, 8, 4, "1")
    g.tri((26, 12), (30, 15), (26, 17), "1")
    g.outline()
    return g


def reeve():
    """The ending. Twice the size of anything else, and a crown so it reads as the one
    giving the orders rather than a big squire."""
    g = Grid(CELL * 2, CELL * 2)
    cx, cy = 32, 36
    g.tri((cx - 16, cy + 26), (cx - 12, cy - 4), (cx + 12, cy - 4), "2")
    g.tri((cx - 16, cy + 26), (cx + 12, cy - 4), (cx + 16, cy + 26), "2")
    g.rect(cx - 16, cy + 12, 32, 14, "2")
    g.rect(cx - 18, cy, 36, 8, "1")               # pauldrons
    g.ellipse(cx, cy - 10, 11, 11, "2")
    g.rect(cx - 9, cy - 11, 18, 3, "K")
    for i in range(5):                            # crown
        g.tri((cx - 11 + i * 5, cy - 22), (cx - 9 + i * 5, cy - 30), (cx - 7 + i * 5, cy - 22), "G")
    g.rect(cx - 12, cy - 23, 25, 4, "G")
    g.rect(cx - 12, cy - 22, 25, 1, "H")
    g.rect(cx - 9, cy + 26, 6, 8, "1")
    g.rect(cx + 4, cy + 26, 6, 8, "1")
    g.outline()
    return g


# ---------------------------------------------------------------- ground and props

def ground(light=False):
    """One floor tile. Two shades alternate by row so the lanes read as lanes without a
    drawn grid line."""
    g = Grid(CELL, CELL)
    g.rect(0, 0, CELL, CELL, "U" if light else "u")
    for i in range(7):                            # scattered grit, deterministic
        x = (i * 11 + (5 if light else 0)) % CELL
        y = (i * 7 + 3) % CELL
        g.set(x, y, "s")
        g.set((x + 1) % CELL, y, "s")
    return g


def vein(step):
    """Gold still in the ground, in five stages from rich to spent. Drawn as an overlay
    on the floor tile, so a cell's worth is visible without a number."""
    g = Grid(CELL, CELL)
    # Clustered into a seam rather than sprinkled. Spread evenly across every tile they
    # read as confetti over the whole board instead of as gold in particular ground.
    n = [6, 4, 3, 2, 1][step]
    seam = [(7, 9), (11, 13), (16, 11), (20, 16), (13, 20), (9, 17)]
    for i in range(n):
        x, y = seam[i]
        g.rect(x, y, 2, 2, "G")
        g.set(x, y, "H")
        g.set(x + 1, y + 1, "g")
    return g


def rubble():
    """The Scree's timed rockfall. A heap — it clears, so it must not look like a hole."""
    g = Grid(CELL, CELL)
    g.rect(0, 0, CELL, CELL, "k")
    for i, (x, y, w) in enumerate(((3, 20, 8), (12, 23, 10), (6, 14, 6),
                                   (18, 16, 7), (22, 24, 8), (13, 9, 5))):
        g.rect(x, y, w, 5, "S" if i % 2 else "s")
        g.rect(x, y, w, 1, "S")
    g.outline()
    return g


def collapsed():
    """Ground that has fallen in. A hole with nothing in it — this never comes back, so
    it must not be mistaken for rubble that does."""
    g = Grid(CELL, CELL)
    g.rect(0, 0, CELL, CELL, "K")
    g.line(2, 8, 11, 15, "s", 1)
    g.line(11, 15, 7, 24, "s", 1)
    g.line(16, 4, 22, 13, "s", 1)
    g.line(22, 13, 29, 21, "s", 1)
    return g


def cracking():
    """Ground that goes at the end of this chamber. Shown the whole way through, because
    a collapse you were warned about is a decision and one you were not is a tax."""
    g = Grid(CELL, CELL)
    g.line(3, 5, 12, 14, "R", 1)
    g.line(12, 14, 8, 26, "R", 1)
    g.line(17, 3, 21, 12, "R", 1)
    g.line(21, 12, 28, 22, "R", 1)
    g.rect(0, 0, CELL, 1, "r")
    g.rect(0, CELL - 1, CELL, 1, "r")
    g.rect(0, 0, 1, CELL, "r")
    g.rect(CELL - 1, 0, 1, CELL, "r")
    return g


def water():
    g = Grid(CELL, CELL)
    g.rect(0, 0, CELL, CELL, "B")
    for i in range(5):
        y = 3 + i * 6
        g.rect(2 + (i % 3) * 4, y, 9, 1, "b")
        g.rect(18 - (i % 2) * 5, y + 3, 7, 1, "b")
    return g


def coin():
    g = Grid(10, 10)
    g.ellipse(5, 5, 4, 4, "G")
    g.ellipse(4, 4, 2, 2, "H")
    g.outline()
    return g


def rock():
    g = Grid(8, 8)
    g.ellipse(4, 4, 3, 3, "S")
    g.set(3, 3, "c")
    g.outline()
    return g


def hoard():
    """The pile behind you. Losing it is losing the chamber, so it is the biggest thing
    on the board that is not a hero."""
    g = Grid(CELL * 2, CELL + 16)
    for i in range(11):
        w = 62 - i * 5
        g.ellipse(32, 44 - i * 3, w // 2, 4, "g" if i % 2 else "G")
    for i in range(18):
        x = (i * 7 + 5) % 56 + 4
        y = 44 - ((i * 5) % 30)
        g.ellipse(x, y, 2, 1, "H")
    g.outline()
    return g
