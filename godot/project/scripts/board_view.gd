## Draws the chamber and turns taps into placements.
##
## Everything is drawn in immediate mode, exactly as the prototype's canvas was. That is
## deliberate for the port: the visuals move across one-to-one and stay editable as
## code, and swapping any one of these `_draw` calls for a real sprite later is a local
## change rather than a rewrite.
class_name BoardView
extends Control

signal goblin_tapped(g: Goblin)
signal ground_tapped(col: int, row: int)

const CAVE := Color("#141119")
const ROW_A := Color("#2a2430")
const ROW_B := Color("#241f26")
const GOLD := Color("#e8c05a")
const ALARM := Color("#d1553f")
const GOBLIN := Color("#6fbf5b")
const DIM := Color("#8a8095")

var sim: ChamberSim
var t: Tuning
var selected: Goblin = null
var held_unit: String = ""

func _ready() -> void:
	t = Game.t
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
		draw_circle(Vector2(s["x"], s["y"]), 5.0, Color("#c9a24a"))
	_draw_hint()

func _draw_ground() -> void:
	for r in range(t.rows):
		var rect := Rect2(t.origin.x, t.origin.y + r * t.cell, t.cols * t.cell, t.cell)
		draw_rect(rect, ROW_A if r % 2 == 0 else ROW_B)
		# A lane that has not opened yet is packed rubble, and the reveal is the only
		# notice you get that a new one is live.
		var shut := 1.0 - sim.lane_reveal[r]
		if shut > 0.01:
			draw_rect(rect, Color(0.06, 0.05, 0.08, 0.9 * shut))
	# The gold in the ground, thickening toward the far end.
	for c in range(t.cols):
		for r in range(t.rows):
			var left: float = sim.veins.get(sim.cell_key(c, r), 1.0)
			if left <= 0.02: continue
			var n := int(2 + c * 1.2)
			for i in range(n):
				var a := fmod(i * 2.399 + c * 1.13 + r * 0.7, 1.0)
				var b := fmod(i * 4.771 + r * 0.61, 1.0)
				var pos := Vector2(t.origin.x + c * t.cell + 8 + a * (t.cell - 16),
					t.origin.y + r * t.cell + 8 + b * (t.cell - 16))
				draw_circle(pos, 2.2, Color(0.79, 0.63, 0.29, 0.25 + left * 0.45))
	for c in range(t.cols + 1):
		var x := t.origin.x + c * t.cell
		draw_line(Vector2(x, t.origin.y), Vector2(x, t.origin.y + t.rows * t.cell),
			Color(1, 1, 1, 0.05))
	for r in range(t.rows + 1):
		var y := t.origin.y + r * t.cell
		draw_line(Vector2(t.origin.x, y), Vector2(t.origin.x + t.cols * t.cell, y),
			Color(1, 1, 1, 0.05))
	# Water sits under the goblins so it reads as ground rather than as a veil.
	for c in sim.flooded:
		draw_rect(Rect2(t.origin.x + c * t.cell, t.origin.y, t.cell, t.rows * t.cell),
			Color(0.11, 0.20, 0.27, 0.82))

## Ground that has already gone. It must not look like rubble, because rubble clears
## and this never does: a hole with nothing in it, not a heap.
func _draw_collapsed() -> void:
	for k in sim.collapsed:
		var bits: PackedStringArray = k.split(",")
		var rect := cell_rect(int(bits[0]), int(bits[1]))
		draw_rect(rect, Color("#08070b"))
		draw_rect(rect.grow(-2), Color(0.27, 0.24, 0.31, 0.6), false, 2.0)

## Ground that goes at the end of THIS chamber, shown the whole time — a collapse you
## were warned about is a decision and one you were not is a tax.
func _draw_cracking() -> void:
	var pulse := 0.5 + sin(sim.clock * 2.1) * 0.5
	for k in sim.cracking:
		if sim.collapsed.has(k): continue
		var bits: PackedStringArray = k.split(",")
		var rect := cell_rect(int(bits[0]), int(bits[1]))
		draw_rect(rect, Color(0.35, 0.16, 0.12, 0.1 + pulse * 0.12))
		draw_rect(rect.grow(-3), Color(ALARM, 0.45 + pulse * 0.35), false, 2.0)

func _draw_rubble() -> void:
	for k in sim.buried:
		var bits: PackedStringArray = k.split(",")
		var rect := cell_rect(int(bits[0]), int(bits[1]))
		draw_rect(rect, Color(0.06, 0.05, 0.08, 0.86))
		var left: float = float(sim.buried[k]) / t.rubble_life
		draw_rect(Rect2(rect.position.x + 8, rect.end.y - 9,
			(t.cell - 16) * clampf(left, 0.0, 1.0), 2.5), Color(GOLD, 0.5))

func _draw_column_warning() -> void:
	if sim.call_lane < 0 or sim.call_t <= 0.0: return
	var pulse := 0.5 + sin(sim.clock * 6.0) * 0.5
	var rect := Rect2(t.origin.x, t.origin.y + sim.call_lane * t.cell,
		t.cols * t.cell, t.cell)
	draw_rect(rect, Color(ALARM, 0.06 + pulse * 0.09))
	draw_rect(rect.grow(-2), Color(ALARM, 0.45 + pulse * 0.4), false, 3.0)

func _draw_caravan() -> void:
	draw_rect(Rect2(0, t.origin.y, t.origin.x, t.rows * t.cell), Color("#1b1720"))
	var base := size.y - 14
	for i in range(24):
		var a := fmod(i * 2.399, 1.0)
		var b := fmod(i * 4.771, 1.0)
		draw_circle(Vector2(8 + a * 78, base - 10 - b * 70), 5.0, GOLD)

# ---------------------------------------------------------------- bodies

func _tint_of(parts: Array) -> Color:
	# The body takes the colour of whatever it has most of, so a fused crew still reads
	# as "mostly wall" or "mostly shooter" at a glance.
	var best := ""
	var best_n := 0
	for p in parts:
		var n := Fusion.count_of(parts, p)
		if n > best_n: best_n = n; best = p
	return Game.units[best].tint if best != "" else GOBLIN

func _draw_goblin(g: Goblin) -> void:
	var rect := cell_rect(g.col, g.row)
	var mid := rect.position + Vector2(t.cell * 0.5, t.cell * 0.55)
	var tint := _tint_of(g.parts)
	if g.entombed: tint = tint.darkened(0.55)

	draw_circle(mid + Vector2(0, 18), 15.0, Color(0, 0, 0, 0.34))
	# One goblin drawn per part, so a three-part body is visibly three of them.
	var n := g.parts.size()
	for i in range(n):
		var off := Vector2((i - (n - 1) * 0.5) * 13.0, -i * 4.0)
		var c: Color = Game.units[g.parts[i]].tint
		if g.hurt > 0.0: c = Color("#fff3cf")
		draw_circle(mid + off, 17.0, c)
		draw_circle(mid + off + Vector2(-5, -3), 3.0, Color("#1a1520"))
		draw_circle(mid + off + Vector2(5, -3), 3.0, Color("#1a1520"))

	var mx := g.max_hp(t, Game.units)
	if g.hp < mx:
		var frac := clampf(g.hp / mx, 0.0, 1.0)
		draw_rect(Rect2(mid.x - 20, rect.end.y - 12, 40, 4), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(mid.x - 20, rect.end.y - 12, 40 * frac, 4),
			ALARM if frac < 0.35 else GOBLIN)
	if selected == g:
		draw_rect(rect.grow(-3), Color(GOLD, 0.75), false, 2.0)
	# A body that has room for what you are holding says so.
	elif held_unit != "" and g.parts.size() < t.max_parts:
		draw_arc(mid, t.cell * 0.42, 0, TAU, 24, Color(GOLD, 0.35), 1.6)

## A goblin on the road. Same body, off its cell, with a health bar — the point of the
## march is that you can watch it not make it.
func _draw_walker(w: Dictionary) -> void:
	var p: Vector2 = w["pos"]
	var hop := absf(sin(w["step"])) * 5.0
	draw_circle(p + Vector2(0, 16), 14.0, Color(0, 0, 0, 0.34))
	var c := _tint_of(w["parts"])
	if w["hurt"] > 0.0: c = Color("#fff3cf")
	draw_circle(p - Vector2(0, hop), 16.0, c)
	draw_arc(p - Vector2(0, hop), 17.5, 0, TAU, 20, Color(GOLD, 0.85), 2.0)
	var frac: float = clampf(w["hp"] / maxf(1.0, w["max_hp"]), 0.0, 1.0)
	if frac < 1.0:
		draw_rect(Rect2(p.x - 16, p.y + 22, 32, 3.5), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(p.x - 16, p.y + 22, 32 * frac, 3.5),
			ALARM if frac < 0.35 else GOBLIN)

## Heroes are told apart by outline, not colour — a cone and a bucket read in
## silhouette. Measured as pairwise overlap, they were the same blob at different scales
## before each got a shape of its own.
func _draw_foe(f: Foe) -> void:
	var d: FoeDef = Game.foes[f.kind]
	var y := t.origin.y + f.lane_f * t.cell + t.cell * 0.56
	var pos := Vector2(f.x, y + sin(f.bob) * 2.0)
	var scale := 1.75 if d.boss else (0.9 if f.kind == "scout"
		else (1.16 if f.kind == "sergeant" else (0.8 if f.kind == "runner" else 1.0)))
	var body := Color("#8f4634") if d.boss else (
		Color("#8d8496") if f.kind == "scout" else (
		Color("#b98a4e") if f.kind == "sergeant" else (
		Color("#d8c9a0") if f.kind == "runner" else Color("#c9ced8"))))
	if f.hit_flash > 0.0: body = Color("#fff3cf")

	draw_circle(Vector2(f.x, y + 30 * scale), 13.0 * scale, Color(0, 0, 0, 0.3))
	var bw := 0.72 if f.kind == "scout" else (0.76 if f.kind == "runner" else 1.0)
	var torso := PackedVector2Array([
		pos + Vector2(-13 * bw, 26) * scale, pos + Vector2(-9 * bw, -8) * scale,
		pos + Vector2(9 * bw, -8) * scale, pos + Vector2(13 * bw, 26) * scale])
	draw_colored_polygon(torso, body)
	draw_circle(pos + Vector2(0, -14) * scale, 12.0 * scale, body)

	match f.kind:
		"squire":                                     # a round shield on the near arm
			draw_circle(pos + Vector2(-16, 8) * scale, 11.0 * scale, Color("#6d6a76"))
		"scout":                                      # a plume twice the head's height
			draw_line(pos + Vector2(-1, -22) * scale, pos + Vector2(20, -44) * scale,
				Color("#d1553f"), 4.0 * scale)
		"sergeant":                                   # pauldrons flatten the top
			draw_rect(Rect2(pos + Vector2(-21, -9) * scale,
				Vector2(42, 10) * scale), Color("#8a6234"))
		"runner":                                     # bare head, hair streaming back
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(6, -22) * scale, pos + Vector2(26, -15) * scale,
				pos + Vector2(24, -7) * scale, pos + Vector2(6, -10) * scale]),
				Color("#8a7a55"))

	if f.slow_for > 0.0:
		draw_circle(Vector2(f.x, y + t.cell * 0.28), 6.0, Color("#9a7fc4"))
	if f.stun_for > 0.0:
		draw_circle(Vector2(f.x, y - 34 * scale), 4.0, GOLD)
	var frac := clampf(f.hp / f.max_hp, 0.0, 1.0)
	if frac < 1.0:
		var w := 32.0 * (2.0 if d.boss else 1.0)
		draw_rect(Rect2(f.x - w * 0.5, y + 32 * scale, w, 3.5), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(f.x - w * 0.5, y + 32 * scale, w * frac, 3.5), ALARM)

func _draw_hint() -> void:
	if sim.call_lane >= 0 and sim.call_t > 0.0:
		var y := t.origin.y + sim.call_lane * t.cell + 22
		draw_string(ThemeDB.fallback_font, Vector2(t.origin.x + 12, y),
			"THEY MASS HERE — %.1fs" % sim.call_t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ALARM)
