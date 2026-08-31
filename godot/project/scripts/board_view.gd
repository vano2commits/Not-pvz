## Draws the chamber and turns taps into placements.
##
## Everything is a sprite from `art/`, authored at 32px a cell and drawn at 3x. The board
## stays on 96px cells — every balance number in the game was swept against that — and
## because 3 is an integer, nothing is ever resampled and the art stays pixel-perfect.
## Project settings pin the default texture filter to nearest, which is the other half of
## keeping it crisp.
class_name BoardView
extends Control

signal goblin_tapped(g: Goblin)
signal ground_tapped(col: int, row: int)

## Sprites are authored at 32px a cell; the board runs on 96px cells.
const ART := 32
const SCALE := 3

const CAVE := Color("#141119")
const GOLD := Color("#e8c05a")
const ALARM := Color("#d1553f")
const GOBLIN := Color("#6fbf5b")

var sim: ChamberSim
var t: Tuning
var selected: Goblin = null
var held_unit: String = ""

var tex: Dictionary = {}

func _load_art() -> void:
	for n in ["goblin_chucker", "goblin_digger", "goblin_barricade", "goblin_sapper",
			"hero_squire", "hero_scout", "hero_sergeant", "hero_runner", "hero_leaper",
			"hero_pavise", "hero_reeve", "tile_ground_a", "tile_ground_b", "tile_rubble",
			"tile_collapsed", "tile_cracking", "tile_water", "prop_coin", "prop_rock",
			"prop_hoard", "tile_vein_0", "tile_vein_1", "tile_vein_2", "tile_vein_3",
			"tile_vein_4"]:
		tex[n] = load("res://art/%s.png" % n)

## Draw a sprite with its top-left at `at`, at the project's integer art scale.
func _blit(art_name: String, at: Vector2, tone: Color = Color.WHITE) -> void:
	var tx: Texture2D = tex.get(art_name)
	if tx == null: return
	draw_texture_rect(tx, Rect2(at, tx.get_size() * SCALE), false, tone)

func _ready() -> void:
	t = Game.t
	_load_art()
	custom_minimum_size = Vector2(t.origin.x + t.cols * t.cell + 20,
		t.origin.y + t.rows * t.cell + 24)

func _process(_delta: float) -> void:
	queue_redraw()

func cell_rect(c: int, r: int) -> Rect2:
	return Rect2(t.origin.x + c * t.cell, t.origin.y + r * t.cell, t.cell, t.cell)

func _gui_input(event: InputEvent) -> void:
	if sim == null or sim.over: return
	if not (event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	var c := int(floor((p.x - t.origin.x) / t.cell))
	var r := int(floor((p.y - t.origin.y) / t.cell))
	if c < 0 or c >= t.cols or r < 0 or r >= t.rows: return

	if held_unit != "":
		if sim.place(held_unit, c, r):
			held_unit = ""
		return
	var occ := sim.goblin_at(c, r)
	# A goblin already on the board can be folded into another one. This is how a
	# worked-out Digger gets reused instead of dug up for nothing.
	if selected != null and occ != null and occ != selected:
		if sim.merge(selected, occ):
			selected = null
			return
	selected = occ if occ != selected else null
	goblin_tapped.emit(selected)
	ground_tapped.emit(c, r)

func _draw() -> void:
	if sim == null: return
	draw_rect(Rect2(Vector2.ZERO, size), CAVE)
	_draw_ground()
	_draw_collapsed()
	_draw_cracking()
	_draw_rubble()
	_draw_column_warning()
	_draw_caravan()
	for g in sim.goblins: _draw_goblin(g)
	for w in sim.walkers: _draw_walker(w)
	for f in sim.foes: _draw_foe(f)
	for s in sim.shots:
		_blit("prop_rock", Vector2(s["x"] - 12, s["y"] - 12))
	_draw_hint()

func _draw_ground() -> void:
	for r in range(t.rows):
		for c in range(t.cols):
			var at := Vector2(t.origin.x + c * t.cell, t.origin.y + r * t.cell)
			_blit("tile_ground_a" if r % 2 == 0 else "tile_ground_b", at)
			# What is still in the ground, in five stages. A cell's worth is visible
			# without a number on it.
			var left: float = sim.veins.get(sim.cell_key(c, r), 1.0)
			if left > 0.02:
				var stage := 4 - clampi(int(left * 5.0), 0, 4)
				_blit("tile_vein_%d" % stage, at)
		# A lane that has not opened yet is dark, and the reveal is the only notice you
		# get that a new one is live.
		var shut := 1.0 - sim.lane_reveal[r]
		if shut > 0.01:
			draw_rect(Rect2(t.origin.x, t.origin.y + r * t.cell,
				t.cols * t.cell, t.cell), Color(0.05, 0.04, 0.06, 0.92 * shut))
	for c in sim.flooded:
		for r in range(t.rows):
			_blit("tile_water", Vector2(t.origin.x + c * t.cell, t.origin.y + r * t.cell))

func _draw_collapsed() -> void:
	for k in sim.collapsed:
		var bits: PackedStringArray = k.split(",")
		_blit("tile_collapsed", Vector2(t.origin.x + int(bits[0]) * t.cell,
			t.origin.y + int(bits[1]) * t.cell))

func _draw_cracking() -> void:
	var pulse := 0.55 + sin(sim.clock * 2.1) * 0.45
	for k in sim.cracking:
		if sim.collapsed.has(k): continue
		var bits: PackedStringArray = k.split(",")
		_blit("tile_cracking", Vector2(t.origin.x + int(bits[0]) * t.cell,
			t.origin.y + int(bits[1]) * t.cell), Color(1, 1, 1, 0.45 + pulse * 0.55))

func _draw_rubble() -> void:
	for k in sim.buried:
		var bits: PackedStringArray = k.split(",")
		var at := Vector2(t.origin.x + int(bits[0]) * t.cell,
			t.origin.y + int(bits[1]) * t.cell)
		_blit("tile_rubble", at)
		var left: float = float(sim.buried[k]) / t.rubble_life
		draw_rect(Rect2(at.x + 8, at.y + t.cell - 9,
			(t.cell - 16) * clampf(left, 0.0, 1.0), 3), Color(GOLD, 0.6))

func _draw_column_warning() -> void:
	if sim.call_lane < 0 or sim.call_t <= 0.0: return
	var pulse := 0.5 + sin(sim.clock * 6.0) * 0.5
	var rect := Rect2(t.origin.x, t.origin.y + sim.call_lane * t.cell,
		t.cols * t.cell, t.cell)
	draw_rect(rect, Color(ALARM, 0.06 + pulse * 0.09))
	draw_rect(rect.grow(-2), Color(ALARM, 0.45 + pulse * 0.4), false, 3.0)

func _draw_caravan() -> void:
	draw_rect(Rect2(0, t.origin.y, t.origin.x, t.rows * t.cell), Color("#1b1720"))
	var hoard: Texture2D = tex.get("prop_hoard")
	if hoard != null:
		var h := hoard.get_size() * SCALE
		_blit("prop_hoard", Vector2(-h.x * 0.28, size.y - h.y - 6))

# ---------------------------------------------------------------- bodies

## The part a body has most of decides which sprite it wears, so a fused crew still
## reads as "mostly wall" or "mostly shooter" at a glance. The rest of the mixture is
## shown as pips under it rather than by blending sprites, which at this size would just
## make mud.
func _dominant(parts: Array) -> String:
	var best := ""
	var best_n := 0
	for p in parts:
		var n := Fusion.count_of(parts, p)
		if n > best_n:
			best_n = n
			best = p
	return best

func _draw_goblin(g: Goblin) -> void:
	var at := Vector2(t.origin.x + g.col * t.cell, t.origin.y + g.row * t.cell)
	var mid := at + Vector2(t.cell * 0.5, t.cell * 0.55)
	var tone := Color.WHITE
	if g.entombed: tone = Color(0.45, 0.42, 0.5)
	elif g.hurt > 0.0: tone = Color(2.2, 2.2, 2.2)
	_blit("goblin_%s" % _dominant(g.parts), at, tone)

	# one pip per part, so a three-part body is visibly three of them
	if g.parts.size() > 1:
		var n := g.parts.size()
		for i in range(n):
			var px := mid.x + (i - (n - 1) * 0.5) * 9.0
			draw_rect(Rect2(px - 3, at.y + 4, 6, 6), Color.BLACK)
			draw_rect(Rect2(px - 2, at.y + 5, 4, 4), Game.units[g.parts[i]].tint)

	var mx := g.max_hp(t, Game.units)
	if g.hp < mx:
		var frac := clampf(g.hp / mx, 0.0, 1.0)
		draw_rect(Rect2(mid.x - 21, at.y + t.cell - 11, 42, 5), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(mid.x - 20, at.y + t.cell - 10, 40 * frac, 3),
			ALARM if frac < 0.35 else GOBLIN)
	if selected == g:
		draw_rect(Rect2(at, Vector2(t.cell, t.cell)).grow(-3), Color(GOLD, 0.85), false, 3.0)
	elif held_unit != "" and g.parts.size() < t.max_parts:
		# a body with room for what you are holding says so
		draw_arc(mid, t.cell * 0.42, 0, TAU, 20, Color(GOLD, 0.4), 2.0)

## A goblin on the road. Same sprite, off its cell, with a health bar — the point of the
## march is that you can watch it not make it.
func _draw_walker(w: Dictionary) -> void:
	var p: Vector2 = w["pos"]
	var hop := absf(sin(w["step"])) * 4.0
	var at := p - Vector2(t.cell * 0.5, t.cell * 0.55 + hop)
	_blit("goblin_%s" % _dominant(w["parts"]), at,
		Color(2.2, 2.2, 2.2) if w["hurt"] > 0.0 else Color.WHITE)
	var frac: float = clampf(w["hp"] / maxf(1.0, w["max_hp"]), 0.0, 1.0)
	draw_rect(Rect2(p.x - 21, p.y + 18, 42, 5), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(p.x - 20, p.y + 19, 40 * frac, 3), ALARM if frac < 0.35 else GOBLIN)

func _draw_foe(f: Foe) -> void:
	var d: FoeDef = Game.foes[f.kind]
	var y := t.origin.y + f.lane_f * t.cell
	var bob := sin(f.bob) * 2.0
	var art_name := "hero_%s" % f.kind
	var tx: Texture2D = tex.get(art_name)
	var w: float = (tx.get_width() * SCALE) if tx != null else t.cell
	var at := Vector2(f.x - w * 0.5, y + t.cell - (tx.get_height() * SCALE if tx else t.cell) - 4 + bob)
	var tone := Color(2.2, 2.2, 2.2) if f.hit_flash > 0.0 else Color.WHITE
	if f.slow_for > 0.0: tone = Color(0.72, 0.66, 0.86)
	_blit(art_name, at, tone)
	if f.stun_for > 0.0:
		draw_circle(Vector2(f.x, at.y - 6), 4.0, GOLD)
	var frac := clampf(f.hp / f.max_hp, 0.0, 1.0)
	if frac < 1.0:
		var bw := 34.0 * (2.0 if d.boss else 1.0)
		draw_rect(Rect2(f.x - bw * 0.5, y + t.cell - 6, bw, 5), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(f.x - bw * 0.5 + 1, y + t.cell - 5, (bw - 2) * frac, 3), ALARM)

func _draw_hint() -> void:
	if sim.call_lane >= 0 and sim.call_t > 0.0:
		var y := t.origin.y + sim.call_lane * t.cell + 22
		draw_string(ThemeDB.fallback_font, Vector2(t.origin.x + 12, y),
			"THEY MASS HERE — %.1fs" % sim.call_t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ALARM)
