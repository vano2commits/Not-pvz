## Autoload. Loads the tuning resource and the definitions, so every other script reads
## its numbers from one place and the editor is the only thing that edits them.
extends Node

const TUNING_PATH := "res://data/tuning.tres"

var t: Tuning
var units: Dictionary = {}     # id -> UnitDef
var foes: Dictionary = {}      # id -> FoeDef
var worlds: Dictionary = {}    # id -> WorldDef

## Six chambers, two worlds. The Rot and The Deep are the reason to want the full game,
## so they are not in the demo at all.
const ROUTE := ["hollow", "hollow", "scree", "scree", "scree", "scree"]
const CHAMBERS := 6

func _ready() -> void:
	t = load(TUNING_PATH) as Tuning
	if t == null:
		push_warning("tuning.tres missing — falling back to script defaults")
		t = Tuning.new()
	for id in ["chucker", "digger", "barricade", "sapper"]:
		units[id] = load("res://data/units/%s.tres" % id) as UnitDef
	for id in ["squire", "scout", "sergeant", "leaper", "pavise", "runner", "reeve"]:
		foes[id] = load("res://data/foes/%s.tres" % id) as FoeDef
	for id in ["hollow", "scree"]:
		worlds[id] = load("res://data/worlds/%s.tres" % id) as WorldDef

func world_for(chamber: int) -> WorldDef:
	return worlds[ROUTE[clampi(chamber, 1, CHAMBERS) - 1]]

## The Sapper is handed to you on arrival in The Scree, which keeps the "each world
## gives you its own answer" beat with the smallest roster that can carry it.
func roster_for(chamber: int) -> Array[String]:
	var r: Array[String] = ["chucker", "digger", "barricade"]
	if world_for(chamber).id == &"scree":
		r.append("sapper")
	return r

## Chamber five gets the column, chamber six the Reeve. Running both in the last
## chamber meant a column, then another column, then the boss, with no room to rebuild.
func waves_for(chamber: int) -> Array:
	var out: Array = []
	var n: int = t.chamber_waves[clampi(chamber, 1, CHAMBERS) - 1]
	for i in range(mini(n, WaveTable.WAVES.size())):
		out.append(WaveTable.WAVES[i])
	if chamber == CHAMBERS - 1: out.append(WaveTable.COLUMN)
	if chamber == CHAMBERS: out.append(WaveTable.BOSS)
	return out
