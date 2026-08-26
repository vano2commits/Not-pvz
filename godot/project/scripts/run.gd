## Autoload. One run: six chambers, a board that never resets, and ground that does.
##
## Persistence alone was what broke this in the prototype — the board and the purse both
## grew with no ceiling, so waves could not be tuned against an arrival state nobody
## could predict. Taking cells away restores the ceiling: maximum board power at chamber
## N is usable_cells(N) x max_parts, a number that was written down rather than one that
## emerged.
extends Node

signal chamber_ready
signal run_ended(won: bool)

var chamber: int = 1
var gold: int = -1                    # -1 means "use the opening"
var board: Array = []
var veins: Dictionary = {}
var seen: Dictionary = {}
var traps: Array[bool] = []

var collapsed: Dictionary = {}
var cracking: Dictionary = {}

var flooded: Array[int] = []
var shut_lanes: Array[int] = []

var kills: int = 0
var dead: int = 0
var marches: int = 0
var feats: Dictionary = {}
var lost_to_collapse: int = 0

func begin() -> void:
	chamber = 1
	gold = -1
	board.clear(); veins.clear(); seen.clear(); traps.clear()
	collapsed.clear(); cracking.clear()
	flooded.clear(); shut_lanes.clear()
	kills = 0; dead = 0; marches = 0
	feats.clear(); lost_to_collapse = 0
	cracking = pick_cracking(collapsed, 2)

func config() -> Dictionary:
	return {
		"world": Game.world_for(chamber),
		"chamber": chamber,
		"units": Game.units,
		"foes": Game.foes,
		"waves": Game.waves_for(chamber),
		"board": board,
		"carry_gold": gold,
		"veins": veins,
		"seen": seen,
		"traps": traps,
		"collapsed": collapsed,
		"cracking": cracking,
		"flooded": flooded,
		"shut_lanes": shut_lanes,
	}

## Fold a finished chamber back into the run. Returns true if the run continues.
func absorb(rep: Dictionary, won: bool) -> bool:
	for k in rep["seen"]: seen[k] = true
	kills += rep["kills"]
	dead += rep["deaths"]
	marches += rep["marches"]
	if rep["paid_for_itself"]: feats["paid"] = true
	if won and rep["deaths"] == 0: feats["scratch"] = true
	if seen.has("barricade+barricade+barricade"): feats["wall"] = true
	if seen.size() >= 5: feats["read"] = true
	if not won:
		run_ended.emit(false)
		return false

	veins = rep["veins"]
	traps = rep["traps"]
	gold = rep["gold"]

	# The cracks you were warned about last chamber give way now. Anything still
	# standing on one goes down with it — the whole chamber was the notice.
	lost_to_collapse = 0
	for k in cracking: collapsed[k] = true
	var kept: Array = []
	for b in rep["board"]:
		if collapsed.has("%d,%d" % [b["col"], b["row"]]):
			lost_to_collapse += b["parts"].size()
		else:
			kept.append(b)
	board = kept
	dead += lost_to_collapse
	cracking = pick_cracking(collapsed, chamber + 2)

	if chamber >= Game.CHAMBERS:
		run_ended.emit(true)
		return false
	chamber += 1
	chamber_ready.emit()
	return true

## Which cells give way next. Heroes arrive from the right and the seams are richest
## there, so collapsing right-to-left takes income and forward position in one stroke
## and reads as a tunnel closing in. Two rules are inviolable: a lane is never sealed,
## and the last column before the cart never goes — randomness may add pressure, but it
## may never own a place to stand.
func pick_cracking(done: Dictionary, for_chamber: int) -> Dictionary:
	var t: Tuning = Game.t
	var out: Dictionary = {}
	var idx := clampi(for_chamber, 1, t.collapsed_by_chamber.size()) - 1
	var want: int = t.collapsed_by_chamber[idx] - done.size()
	if want <= 0: return out

	var lane_left: Array[int] = []
	for r in range(t.rows):
		var n := 0
		for c in range(t.cols):
			if not done.has("%d,%d" % [c, r]): n += 1
		lane_left.append(n)

	var pool: Array = []
	for r in range(t.rows):
		for c in range(t.cols):
			if done.has("%d,%d" % [c, r]) or t.safe_cols.has(c): continue
			pool.append({ "c": c, "r": r,
				"w": pow(c + 1, t.right_bias) * (0.6 + randf()) })
	pool.sort_custom(func(a, b): return a["w"] > b["w"])

	for cell in pool:
		if out.size() >= want: break
		if lane_left[cell["r"]] - 1 < t.min_per_lane: continue
		out["%d,%d" % [cell["c"], cell["r"]]] = true
		lane_left[cell["r"]] -= 1
	return out

func usable_cells() -> int:
	return Game.t.cols * Game.t.rows - collapsed.size()
