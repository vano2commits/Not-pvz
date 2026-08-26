## Every number the game plays by, in one inspector panel.
##
## This is the reason the project moved off a single HTML file: open
## `data/tuning.tres` in the editor and every value below is a field you can drag,
## with the game reloading on the next run. Nothing here is read at parse time, so
## changing a number never means touching code.
##
## The values shipped in `tuning.tres` are the ones swept in the prototype. Where a
## number has a comment, the comment is why it is that number — most of them were
## measured rather than chosen, and the sweep is the only reason to trust them.
class_name Tuning
extends Resource

# ---------------------------------------------------------------- board
@export_group("Board")
## Columns, rows and the pixel size of a cell. The prototype's 7x5x96 board.
@export var cols: int = 7
@export var rows: int = 5
@export var cell: int = 96
## Board origin inside the play area, in pixels. x leaves room for the caravan.
@export var origin: Vector2i = Vector2i(96, 52)
## The order lanes open in during the chamber-one tutorial: middle outward.
@export var lane_order: Array[int] = [2, 1, 3, 0, 4]

# ---------------------------------------------------------------- economy
@export_group("Economy")
## Opening gold, once, at the top of the run. Everything after chamber one is gold
## you earned and kept — the board persists, so there is nothing to re-buy.
@export var start_coins: int = 400
## A pull is worth `(base + col * per_col) * richness`. The gradient is the whole
## economic decision: the money is to the right and so is everything that kills you.
@export var yield_base: float = 3.0
@export var yield_per_col: float = 1.5
## Seconds between payouts, and how long a fresh Digger takes to reach full output.
@export var dig_every: float = 5.0
@export var dig_warm: float = 18.0
## What a Digger pulls the moment it lands, as a fraction of its full rate.
@export var dig_floor: float = 0.5
## Payouts one cell has in it before the pocket is dry. At 999 six Diggers peaked at
## 893 gold and the economy stopped mattering; at 26 they peak at 272 against three
## Diggers' 256, so spamming them stops paying.
@export var vein_pulls: int = 26
## A closing tunnel pushes you onto the deep seam, so what is left pays more. Without
## this the collapse compounds against itself — fewer cells means fewer Diggers means
## less gold means fewer bodies — and the run dies of poverty rather than of heroes.
@export var richness_gain: float = 1.9

# ---------------------------------------------------------------- fusion
@export_group("Fusion")
## Parts a single body can hold.
@export var max_parts: int = 3
## Pooled health is discounted for a mixed body, or two cheap parts would out-tank a
## Barricade.
@export var hybrid_hp: float = 0.72
## How fast a goblin crosses the board when merged into another, in pixels a second.
## The march is the point: anything whose lane it crosses gets a swing at it.
@export var walk_speed: float = 118.0
## Seconds after placing during which digging one up is a full refund — a moment's
## grace for a misclick. After that it returns the tile and nothing else.
@export var dig_up_grace: float = 3.0

# ---------------------------------------------------------------- pacing
@export_group("Pacing")
## Waves in each of the six chambers. Chamber five also gets the column and chamber
## six the Reeve, both appended on top of these.
@export var chamber_waves: Array[int] = [3, 3, 4, 4, 4, 3]
## Hero health multiplier per chamber: 1 + (chamber - 1) * this.
@export var hp_scale_per_chamber: float = 0.17
## Seconds of quiet between waves. Long enough to spend a purse in; three was not.
@export var breath: float = 2.2
## The next wave arrives when the current one drops below this share of its health,
## the way the original does it. Skipped on the last wave of a chamber — pulling a
## next wave forward when there is no next wave ends the chamber with heroes still
## walking.
@export var next_wave_at: float = 0.45

# ---------------------------------------------------------------- collapsing ground
@export_group("Collapsing ground")
## Cumulative cells gone by the START of each chamber, out of 35. The board never
## resets; the ground does. Persistence alone was what broke this before — board and
## purse both grew with no ceiling — and taking cells away restores it: maximum board
## power at chamber N is usable_cells(N) x max_parts, a number that was written down
## rather than one that emerged.
@export var collapsed_by_chamber: Array[int] = [0, 2, 5, 8, 12, 16]
## Cells are weighted (col + 1) ^ this when choosing what falls in. Heroes arrive from
## the right and the seams are richest there, so collapsing right-to-left takes income
## and forward position in one stroke.
@export var right_bias: float = 1.0
## A lane is never left with fewer usable cells than this, and these columns never go.
## Randomness may add pressure; it may never own a place to stand.
@export var min_per_lane: int = 2
@export var safe_cols: Array[int] = [0]

# ---------------------------------------------------------------- the Scree
@export_group("The Scree")
## Seconds a rockfall sits before it settles on its own, and seconds between falls.
@export var rubble_life: float = 18.0
@export var rubble_every: float = 12.0
## Never more than this many cells buried at once, or the board quietly disappears.
@export var rubble_max: int = 3
## How long a Sapper takes to clear a cell in its lane, and to dig ITSELF out. A
## buried Sapper used to be frozen like anything else, which took the lane's answer to
## rockfall out of service for the full eighteen seconds with nothing to do about it.
@export var sapper_clear: float = 2.2
@export var sapper_self_dig: float = 4.4

# ---------------------------------------------------------------- combat
@export_group("Combat")
## Damage and cooldown by how many Chuckers are in the body. Flat damage-per-gold on
## purpose: 0.242, 0.240, 0.242. PvZ runs Peashooter and Repeater both at 0.140 and
## Gatling at 0.125. An earlier build ran 0.242 / 0.551 / 0.714 and a single stacked
## lane held everything by wave four.
@export var shot_damage: Array[int] = [22, 42, 61]
@export var shot_cooldown: Array[float] = [1.3, 1.25, 1.2]
## A body with no actual Chucker in it throws gravel, not rocks.
@export var gravel_damage: int = 12
@export var gravel_cooldown: float = 1.7
## Pixels a Sapper's shove moves a hero, per Sapper, and the hard cap. At 12 a shove
## beat a squire's 28px of walking outright and three Sappers drove heroes backwards
## off the right edge of the board.
@export var shove_per_sapper: float = 4.0
@export var shove_cap: float = 10.0
