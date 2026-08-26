## The fight. No drawing, no input, no scene tree — just state and `step(delta)`.
##
## Keeping the simulation headless is what made the prototype's balance work possible:
## a harness can run thousands of chambers faster than real time and read the
## distribution, instead of one person playing and forming an impression. Anything that
## needs to be true about the game should be checkable by calling `step` in a loop, so
## nothing in this file may touch a Node.
class_name ChamberSim
extends RefCounted

signal chamber_won
signal chamber_lost
signal gold_changed(total: int)
signal body_first_built(g: Goblin)
signal wave_started(index: int, wave_name: String)
signal column_incoming(lane: int, seconds: float)

const CARAVAN_X := 96.0

var t: Tuning
var units: Dictionary = {}          # id -> UnitDef
var foes_def: Dictionary = {}       # id -> FoeDef
var world: WorldDef

var chamber: int = 1
var coins: int = 0
var goblins: Array[Goblin] = []
var foes: Array[Foe] = []
var shots: Array = []
var walkers: Array = []

## col,row -> seconds left. The Scree's timed rubble.
var buried: Dictionary = {}
## col,row -> true. Ground that has fallen in and never comes back.
var collapsed: Dictionary = {}
## col,row -> true. Ground that goes at the END of this chamber, shown all the way
## through, because a collapse you were warned about is a decision and one you were
## not is a tax.
var cracking: Dictionary = {}
## col,row -> 0..1 of the pocket left under it.
var veins: Dictionary = {}
## One bear trap per lane for the whole run, not per chamber.
var traps: Array[bool] = []
var flooded: Array[int] = []
var shut_lanes: Array[int] = []

var wave_index: int = -1
var waves: Array = []
var phase: String = "intro"
var phase_t: float = 5.0
var queue: Array = []
var wave_lanes: Array[int] = []
var wave_stack: int = 0
var call_lane: int = -1
var call_t: float = 0.0

var lane_reveal: Array[float] = []
var lane_load: Array[float] = []

var over: bool = false
var won: bool = false
var clock: float = 0.0
var rubble_t: float = 14.0
var next_id: int = 0

## Run-level bookkeeping the ending screen is made of.
var seen: Dictionary = {}
var killed: int = 0
var goblin_deaths: int = 0
var marches: int = 0
var kill_lanes: Dictionary = {}
var chucker_lanes: Dictionary = {}

# ---------------------------------------------------------------- setup

func _init(tuning: Tuning) -> void:
	t = tuning

func begin(cfg: Dictionary) -> void:
	world = cfg["world"]
	chamber = cfg.get("chamber", 1)
	units = cfg["units"]
	foes_def = cfg["foes"]
	waves = cfg["waves"]

	goblins.clear(); foes.clear(); shots.clear(); walkers.clear(); queue.clear()
	buried.clear()
	collapsed = cfg.get("collapsed", {}).duplicate()
	cracking = cfg.get("cracking", {}).duplicate()
	veins = cfg.get("veins", {}).duplicate()
	seen = cfg.get("seen", {}).duplicate()
	flooded.assign(cfg.get("flooded", []))
	shut_lanes.assign(cfg.get("shut_lanes", []))

	traps.assign(cfg.get("traps", []))
	if traps.is_empty():
		traps.resize(t.rows)
		traps.fill(world.bear_traps)

	lane_reveal.resize(t.rows); lane_reveal.fill(0.0)
	lane_load.resize(t.rows); lane_load.fill(0.0)

	coins = cfg.get("carry_gold", -1)
	if coins < 0:
		coins = t.start_coins

	for b in cfg.get("board", []):
		var g := Goblin.new()
		next_id += 1
		g.id = next_id
		g.parts.assign(b["parts"])
		g.col = b["col"]; g.row = b["row"]
		g.age = b.get("age", 0.0)
		g.born = -99.0
		g.hp = maxf(12.0, g.max_hp(t, units) * b.get("hp_frac", 1.0))
		goblins.append(g)

	wave_index = -1
	phase = "intro"; phase_t = 5.0
	over = false; won = false; clock = 0.0
	rubble_t = t.rubble_every
	killed = 0; goblin_deaths = 0; marches = 0
	kill_lanes.clear(); chucker_lanes.clear()

# ---------------------------------------------------------------- board queries

func cell_key(c: int, r: int) -> String:
	return "%d,%d" % [c, r]

## One predicate for "nothing can stand here": timed rubble, water, or a hole.
func blocked(c: int, r: int) -> bool:
	var k := cell_key(c, r)
	return buried.has(k) or collapsed.has(k) or flooded.has(c)

func lanes_open_at(wave_ix: int) -> int:
	# The three-lane opening is a tutorial, and a tutorial you sit through at the top of
	# every chamber is just the game starting slowly six times.
	if chamber != 1:
		return t.rows
	if wave_ix < 3: return 3
	if wave_ix < 4: return 4
	return t.rows

func lane_is_open(r: int) -> bool:
	if shut_lanes.has(r):
		return false
	return t.lane_order.find(r) < lanes_open_at(maxi(wave_index, 0))

func goblin_at(c: int, r: int) -> Goblin:
	for g in goblins:
		if g.col == c and g.row == r and g.hp > 0.0:
			return g
	return null

func lane_y(r: int) -> float:
	return float(t.origin.y + r * t.cell)

## How much you have standing in each lane, in bodies. The Reeve reads this.
func lane_weight(r: int) -> int:
	var n := 0
	for g in goblins:
		if g.row == r and g.hp > 0.0:
			n += g.parts.size()
	return n

func emptiest_lane() -> int:
	var best := -1
	var best_w := 1 << 30
	for r in range(t.rows):
		if not lane_is_open(r):
			continue
		var w := lane_weight(r)
		if best < 0 or w < best_w:
			best = r; best_w = w
	return best if best >= 0 else 2

## A closing tunnel pushes you onto the deep seam, so what is left pays more.
func richness() -> float:
	return 1.0 + (float(collapsed.size()) / 35.0) * t.richness_gain

func yield_at(col: int) -> int:
	return int(round((t.yield_base + col * t.yield_per_col) * richness()))

func rich_max() -> int:
	return yield_at(t.cols - 1)

func hp_scale() -> float:
	return 1.0 + (chamber - 1) * t.hp_scale_per_chamber

func usable_cells() -> int:
	return t.cols * t.rows - collapsed.size()

# ---------------------------------------------------------------- placing

## Try to put `kind` on a cell. Dropping one onto an occupied cell fuses them, which
## is the only way to reach anything past the three you can buy.
func place(kind: String, c: int, r: int) -> bool:
	var u: UnitDef = units.get(kind)
	if u == null: return false
	if not lane_is_open(r): return false
	if blocked(c, r): return false
	if coins < u.cost: return false

	var occ := goblin_at(c, r)
	if occ != null:
		if occ.parts.size() >= t.max_parts:
			return false
		coins -= u.cost
		occ.parts.append(kind)
		occ.hp = occ.max_hp(t, units)
		occ.squash = 1.4
		occ.born = clock
		note_body(occ)
		gold_changed.emit(coins)
		return true

	coins -= u.cost
	var g := Goblin.new()
	next_id += 1
	g.id = next_id
	g.parts = [kind] as Array[String]
	g.col = c; g.row = r
	g.hp = g.max_hp(t, units)
	g.born = clock
	g.land = 1.0
	goblins.append(g)
	note_body(g)
	gold_changed.emit(coins)
	return true

## Digging one up buys back the tile and nothing else, past a moment's grace for a
## misclick. Refunding half made a full board a reversible decision and took the weight
## out of placing at all.
func dig_up(g: Goblin) -> int:
	var back := g.spent(units) if clock - g.born <= t.dig_up_grace else 0
	coins += back
	goblins.erase(g)
	gold_changed.emit(coins)
	return back

## Merging two bodies already on the board is a march, not a teleport. The goblin
## leaves its cell and walks the lanes to the one it is joining, and anything whose lane
## it crosses gets a swing at it on the road.
func merge(src: Goblin, dst: Goblin) -> bool:
	if src == dst: return false
	if src.parts.size() + dst.parts.size() > t.max_parts: return false
	if not lane_is_open(dst.row) or blocked(dst.col, dst.row): return false
	marches += 1
	walkers.append({
		"parts": src.parts.duplicate(),
		"hp": src.hp,
		"max_hp": src.max_hp(t, units),
		"age": src.age,
		"to_id": dst.id,
		"pos": Vector2(t.origin.x + src.col * t.cell + t.cell * 0.5,
			t.origin.y + src.row * t.cell + t.cell * 0.55),
		"step": 0.0, "hurt": 0.0, "stranded": 0.0,
	})
	goblins.erase(src)
	return true

## A body you have never made before is the moment the game is selling.
func note_body(g: Goblin) -> bool:
	var k := g.key()
	if seen.has(k):
		return false
	seen[k] = true
	body_first_built.emit(g)
	return true

# ---------------------------------------------------------------- the step

func step(delta: float) -> void:
	if over: return
	clock += delta
	if call_t > 0.0: call_t = maxf(0.0, call_t - delta)

	_step_lanes(delta)
	_step_walkers(delta)
	_step_rockfall(delta)
	_step_waves(delta)
	_step_goblins(delta)
	_step_shots(delta)
	_step_foes(delta)
	_reap()

func _step_lanes(delta: float) -> void:
	for r in range(t.rows):
		var want := 1.0 if lane_is_open(r) else 0.0
		lane_reveal[r] = move_toward(lane_reveal[r], want, delta * 1.6)

func _step_rockfall(delta: float) -> void:
	if not world.rockfall or phase == "intro":
		return
	for k in buried.keys():
		buried[k] -= delta
		if buried[k] <= 0.0:
			buried.erase(k)
	rubble_t -= delta
	# Never more than a few at once, or the board quietly disappears.
	if rubble_t <= 0.0 and buried.size() < t.rubble_max:
		rubble_t = t.rubble_every
		var free: Array = []
		for c in range(1, t.cols):
			for r in range(t.rows):
				if lane_is_open(r) and not blocked(c, r):
					free.append(Vector2i(c, r))
		if not free.is_empty():
			var pick: Vector2i = free[randi() % free.size()]
			buried[cell_key(pick.x, pick.y)] = t.rubble_life

func _step_waves(delta: float) -> void:
	if phase == "intro":
		phase_t -= delta
		if phase_t <= 0.0: _start_wave()
		return
	if phase == "breath":
		phase_t -= delta
		if phase_t <= 0.0: _start_wave()
		return

	phase_t += delta
	while not queue.is_empty() and queue[0]["at"] <= phase_t:
		var e: Dictionary = queue.pop_front()
		_spawn(e["kind"], e.get("lane", -1))

	var last := wave_index >= waves.size() - 1
	var spent := false
	if not last and queue.is_empty() and not foes.is_empty():
		var hp_now := 0.0
		var hp_max := 0.0
		for f in foes:
			hp_now += f.hp; hp_max += f.max_hp
		spent = hp_now < hp_max * t.next_wave_at
	if queue.is_empty() and (foes.is_empty() or spent):
		phase = "breath"
		# The trigger pulls the NEXT wave forward. On the last one there is no next
		# wave, so it would end the chamber with heroes still walking.
		phase_t = 0.6 if last else t.breath

func _start_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		_victory()
		return
	var w: Dictionary = waves[wave_index]
	var gap: float = 0.42 if w.get("stack", 0) > 0 else maxf(0.5, 1.6 - wave_index * 0.17)
	queue.clear()
	wave_lanes.clear()
	wave_stack = w.get("stack", 0)
	var at := 0.0
	var warn: float = 3.2 if wave_stack > 0 else 0.0
	for kind in w["list"]:
		at += randf_range(gap * 0.65, gap * 1.5)
		queue.append({ "kind": kind, "at": at + warn })
	if wave_stack > 0:
		# A column that turns up unannounced is indistinguishable from a bug.
		call_lane = emptiest_lane()
		call_t = warn
		for e in queue:
			e["lane"] = call_lane
		column_incoming.emit(call_lane, warn)
	else:
		call_lane = -1
		call_t = 0.0
	for r in range(t.rows):
		lane_load[r] *= 0.7
	phase = "fight"
	phase_t = 0.0
	wave_started.emit(wave_index, str(w.get("name", "")))

func _choose_lane() -> int:
	var open: Array[int] = []
	for r in range(t.rows):
		if lane_is_open(r): open.append(r)
	if open.is_empty(): return 2
	# A column goes down the lane you have least in, so it cannot be pre-answered.
	if wave_stack > 0 and wave_lanes.is_empty():
		var e := emptiest_lane()
		wave_lanes.append(e)
		return e
	# Wave one is a single lane, wave two is two: the opening teaches a lane before it
	# teaches anything else.
	var cap := open.size()
	if chamber == 1:
		if wave_index == 0: cap = 1
		elif wave_index == 1: cap = 2
	if wave_stack > 0: cap = mini(cap, wave_stack)
	var pool: Array[int] = wave_lanes if wave_lanes.size() >= cap else open
	var total := 0.0
	var weights: Array[float] = []
	for r in pool:
		var wgt := 1.0 / (1.0 + lane_load[r])
		weights.append(wgt); total += wgt
	var roll := randf() * total
	for i in range(pool.size()):
		roll -= weights[i]
		if roll <= 0.0:
			if not wave_lanes.has(pool[i]): wave_lanes.append(pool[i])
			return pool[i]
	return pool[pool.size() - 1]

func _spawn(kind: String, lane: int = -1) -> void:
	var d: FoeDef = foes_def[kind]
	if lane < 0: lane = _choose_lane()
	var f := Foe.new()
	f.kind = kind
	f.lane = lane
	f.lane_f = float(lane)
	f.x = t.origin.x + t.cols * t.cell + 26.0
	f.hp = round(d.hp * hp_scale())
	f.max_hp = f.hp
	f.speed = d.speed * randf_range(0.82, 1.18)
	f.bob = randf() * 6.28
	foes.append(f)
	lane_load[lane] += d.points

# ---------------------------------------------------------------- goblins

func _step_goblins(delta: float) -> void:
	for g in goblins:
		if g.hp <= 0.0: continue
		var own := cell_key(g.col, g.row)

		# Under a rockfall: still there, still soaks hits, but not working. Except a
		# Sapper, whose whole job is rubble — it digs itself out, and only itself.
		if buried.has(own) and not g.has_pair("shored"):
			g.entombed = true
			if g.count_of("sapper") > 0:
				g.dug_out += delta * g.count_of("sapper")
				if g.dug_out >= t.sapper_self_dig:
					buried.erase(own)
					g.dug_out = 0.0
					g.squash = 1.2
			continue
		g.entombed = false
		g.dug_out = 0.0

		# Propped: props and shoring hold a wall up between attacks.
		if g.has_pair("propped") and clock - g.last_hit > 2.5:
			g.hp = minf(g.max_hp(t, units), g.hp + 9.0 * delta)

		if g.count_of("chucker") > 0: chucker_lanes[g.row] = true
		g.cooldown -= delta
		if g.squash > 0.0: g.squash -= delta * 3.4
		if g.hurt > 0.0: g.hurt -= delta
		if g.land > 0.0: g.land -= delta * 2.6
		if g.recoil > 0.0: g.recoil -= delta * 6.0

		_goblin_shoot(g, delta)
		_goblin_sapper(g, delta)
		_goblin_dig(g, delta)

func _goblin_shoot(g: Goblin, _delta: float) -> void:
	# A Sapper throws too, and a body with no actual Chucker in it throws gravel.
	var cn := g.count_of("chucker") + (1 if g.count_of("sapper") > 0 else 0)
	if cn <= 0: return
	var target: Foe = null
	var gx := t.origin.x + g.col * t.cell
	for f in foes:
		if f.lane == g.row and f.hp > 0.0 and f.x > gx - 10.0:
			target = f
			break
	if target == null or g.cooldown > 0.0: return

	var weak := g.count_of("chucker") == 0
	var tier := clampi(cn, 1, 3) - 1
	var dmg: int = t.gravel_damage if weak else t.shot_damage[tier]
	var cd: float = t.gravel_cooldown if weak else t.shot_cooldown[tier]
	var shove := 0.0
	if g.count_of("sapper") > 0:
		shove = minf(t.shove_cap, t.shove_per_sapper * g.count_of("sapper"))

	g.cooldown = cd
	g.recoil = 1.0
	shots.append({
		"x": gx + t.cell * 0.62,
		"y": t.origin.y + g.row * t.cell + t.cell * 0.46,
		"lane": g.row, "dmg": float(dmg), "shove": shove,
		"tipped": g.has_pair("tipped"),
		"stagger": g.has_pair("staggered"),
	})

## A Sapper keeps its own lane clear of rubble.
func _goblin_sapper(g: Goblin, delta: float) -> void:
	if g.count_of("sapper") <= 0: return
	g.sapper_cd -= delta
	if g.sapper_cd > 0.0: return
	g.sapper_cd = t.sapper_clear
	for k in buried.keys():
		var bits: PackedStringArray = k.split(",")
		if int(bits[1]) == g.row:
			buried.erase(k)
			return

func _goblin_dig(g: Goblin, delta: float) -> void:
	var dn := g.count_of("digger")
	if dn <= 0: return
	g.age += delta
	# More picks means a faster shaft as well as a bigger pull.
	var warm: float = t.dig_floor + (1.0 - t.dig_floor) * minf(1.0, g.age * dn / t.dig_warm)
	var vk := cell_key(g.col, g.row)
	if not veins.has(vk): veins[vk] = 1.0
	var left: float = veins[vk]
	var shored: float = 1.25 if g.has_pair("shored") else 1.0
	var take := int(round(yield_at(g.col) * warm * (1.0 + (dn - 1) * 0.85)
		* world.dig_mult * left * shored))

	g.dig_cooldown -= delta
	if g.dig_cooldown > 0.0: return
	g.dig_cooldown = t.dig_every
	# Every pull takes a bite out of the pocket under it.
	veins[vk] = maxf(0.0, left - (1.0 / t.vein_pulls) * dn * world.bore_mult)
	if take <= 0:
		g.squash = 0.6
		return
	coins += take
	# Strongbox: a wall around a mine is somewhere to put the takings.
	if g.has_pair("strongbox"): g.banked += int(round(take * 0.5))
	g.squash = 1.0
	gold_changed.emit(coins)

# ---------------------------------------------------------------- the road

## Walkers are off the grid, so nothing shoots from them and nothing stands behind
## them. They are a body crossing open ground, which is the whole point.
func _step_walkers(delta: float) -> void:
	var keep: Array = []
	for w in walkers:
		if w["hurt"] > 0.0: w["hurt"] -= delta
		var dst: Goblin = null
		for g in goblins:
			if g.id == w["to_id"] and g.hp > 0.0:
				dst = g; break
		if dst == null:
			# Its destination died under it. There is no wagon to climb back into, so
			# it digs in where it stands rather than evaporating.
			w["stranded"] += delta
			if w["stranded"] > 0.35:
				_land_walker(w)
				continue
			keep.append(w)
			continue

		var target := Vector2(t.origin.x + dst.col * t.cell + t.cell * 0.5,
			t.origin.y + dst.row * t.cell + t.cell * 0.55)
		var to := target - w["pos"]
		w["step"] += delta * 9.0
		if to.length() > 3.0:
			w["pos"] += to.normalized() * t.walk_speed * delta

		var lane := int(floor((w["pos"].y - t.origin.y) / t.cell))
		for f in foes:
			if f.hp <= 0.0 or f.lane != lane: continue
			if absf(f.x - w["pos"].x) > t.cell * 0.55: continue
			w["hp"] -= foes_def[f.kind].dps * delta
			w["hurt"] = 0.14

		if w["hp"] <= 0.0:
			continue                      # lost on the road
		if (target - w["pos"]).length() <= 3.0:
			_arrive(w, dst)
			continue
		keep.append(w)
	walkers = keep

func _land_walker(w: Dictionary) -> void:
	var lane := clampi(int(floor((w["pos"].y - t.origin.y) / t.cell)), 0, t.rows - 1)
	var col := clampi(int(round((w["pos"].x - t.origin.x - t.cell * 0.5) / t.cell)), 0, t.cols - 1)
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for r in range(t.rows):
		for c in range(t.cols):
			if not lane_is_open(r) or blocked(c, r) or goblin_at(c, r) != null: continue
			var d := absi(c - col) + absi(r - lane) * 2
			if best.x < 0 or d < best_d:
				best = Vector2i(c, r); best_d = d
	if best.x < 0:
		return
	var g := Goblin.new()
	next_id += 1
	g.id = next_id
	g.parts.assign(w["parts"])
	g.col = best.x; g.row = best.y
	g.age = w["age"]
	g.hp = clampf(w["hp"], 12.0, g.max_hp(t, units))
	g.born = clock
	g.squash = 1.2
	goblins.append(g)
	note_body(g)

func _arrive(w: Dictionary, dst: Goblin) -> void:
	var kept: float = clampf(w["hp"] / maxf(1.0, w["max_hp"]), 0.2, 1.0)
	for p in w["parts"]:
		dst.parts.append(p)
	var mx := dst.max_hp(t, units)
	# The one that walked over arrives as hurt as it was.
	dst.hp = clampf(maxf(dst.hp, mx * minf(1.0, (dst.hp / mx + kept) * 0.5)), 12.0, mx)
	dst.squash = 1.4
	dst.born = clock
	note_body(dst)

# ---------------------------------------------------------------- shots and heroes

func _step_shots(delta: float) -> void:
	var keep: Array = []
	for s in shots:
		s["x"] += 560.0 * delta
		var hit := false
		for f in foes:
			if f.hp <= 0.0 or f.lane != s["lane"]: continue
			if absf(f.x - s["x"]) > 20.0: continue
			var d: FoeDef = foes_def[f.kind]
			# Pavise shrugs small hits off, so chip damage stops working.
			f.hp -= maxf(1.0, s["dmg"] - d.soak)
			f.hit_flash = 0.12
			f.x += 3.0 + s["shove"]
			if s["tipped"]: f.tipped = true
			# Staggering: the shove does not just move it, it interrupts.
			if s["stagger"]: f.stun_for = maxf(f.stun_for, 0.55)
			hit = true
			break
		if not hit and s["x"] < t.origin.x + t.cols * t.cell + 60.0:
			keep.append(s)
	shots = keep

func _step_foes(delta: float) -> void:
	for f in foes:
		if f.hp <= 0.0: continue
		var d: FoeDef = foes_def[f.kind]
		f.bob += delta * (11.0 if f.kind == "scout" else 7.0)
		if f.hit_flash > 0.0: f.hit_flash -= delta
		if f.slow_for > 0.0: f.slow_for -= delta
		if f.squash > 0.0: f.squash -= delta * 4.0
		if not f.bleeding and f.hp / f.max_hp <= 0.33 and not d.boss:
			f.bleeding = true
		if f.bleeding and not d.boss: f.hp -= 11.0 * delta

		if d.boss: _step_reeve(f, delta)
		if f.stun_for > 0.0:
			f.stun_for -= delta
			continue

		var col := int(floor((f.x - t.origin.x) / t.cell))
		var wall: Goblin = goblin_at(col, f.lane) if col >= 0 and col < t.cols else null

		# A Leaper vaults the first thing in its way, once, and lands clear of it.
		if f.vault >= 0.0:
			f.vault = minf(1.0, f.vault + delta * 1.6)
			f.x = lerpf(f.vault_from, f.vault_to, f.vault)
			if f.vault >= 1.0: f.vault = -1.0
			continue
		if wall != null and d.leaps and not f.leapt:
			f.leapt = true
			f.vault = 0.0
			f.vault_from = f.x
			f.vault_to = f.x - t.cell * 1.35
			continue

		if wall != null:
			# Loopholed: a shooter behind a wall is hard to get at while it is looking
			# at you.
			var soak: float = 0.66 if (wall.has_pair("loophole") and wall.cooldown < 0.9) else 1.0
			wall.hp -= d.dps * soak * delta
			wall.hurt = 0.13
			wall.last_hit = clock
			continue

		f.x -= f.speed * delta * (0.62 if f.slow_for > 0.0 else 1.0)
		if f.x <= CARAVAN_X:
			_reach_caravan(f)

func _step_reeve(f: Foe, delta: float) -> void:
	# It walks the width of the board, not a lane: a steady sweep while it advances.
	# Hunting the emptiest lane on a timer made it unkillable — there is always a
	# softest lane and it just walked down it — and flinching away from damage did the
	# same thing for the same reason. A sweep is indifferent to your board, which is
	# what makes your board the thing being tested.
	f.sweep_t -= delta
	if f.sweep_t <= 0.0:
		f.sweep_t = 2.6
		var next := f.lane + f.sweep_dir
		if next < 0 or next >= t.rows or not lane_is_open(next):
			f.sweep_dir *= -1
			next = f.lane + f.sweep_dir
		if next >= 0 and next < t.rows and lane_is_open(next):
			f.lane = next
			f.squash = 1.2
	f.lane_f = lerpf(f.lane_f, float(f.lane), minf(1.0, delta * 3.4))
	f.call_t -= delta
	if f.call_t <= 0.0:
		f.call_t = 15.0
		var into := emptiest_lane()
		for i in range(2):
			queue.append({ "kind": "sergeant" if i == 1 else "squire",
				"at": phase_t + 0.25 + i * 0.35, "lane": into })
		queue.sort_custom(func(a, b): return a["at"] < b["at"])

func _reach_caravan(f: Foe) -> void:
	var d: FoeDef = foes_def[f.kind]
	# A bear trap is a safety net for a hero, not an answer to the ending. Letting one
	# one-shot the Reeve meant a board stacked into one lane simply won.
	if d.boss:
		f.hp -= 900.0
		if traps[f.lane]:
			traps[f.lane] = false
		f.x = t.origin.x + t.cols * t.cell + 20.0
		f.lane = emptiest_lane()
		f.lane_f = float(f.lane)
		return
	if traps[f.lane]:
		traps[f.lane] = false
		for v in foes:
			if v.lane == f.lane and v.hp > 0.0 and not foes_def[v.kind].boss:
				v.hp = 0.0
				v.by_trap = true
		return
	_defeat()

func _reap() -> void:
	for f in foes:
		if f.hp > 0.0 or f.dead: continue
		f.dead = true
		killed += 1
		kill_lanes[f.lane] = true
		var purse := int(round(foes_def[f.kind].purse * world.purse_mult))
		# Coin-tipped: the shot that landed it was fitted by a Digger.
		if f.tipped: purse = int(round(purse * 1.5))
		purse += f.bounty
		coins += purse
		gold_changed.emit(coins)
	var live_foes: Array[Foe] = []
	for f in foes:
		if f.hp > 0.0: live_foes.append(f)
	foes = live_foes

	for g in goblins:
		if g.hp > 0.0 or g.mourned: continue
		g.mourned = true
		goblin_deaths += 1
		if g.banked > 0:
			coins += g.banked          # Strongbox: the takings survive it
			gold_changed.emit(coins)
	var live_gobs: Array[Goblin] = []
	for g in goblins:
		if g.hp > 0.0: live_gobs.append(g)
	goblins = live_gobs

func _victory() -> void:
	if over: return
	# Anyone still on the road when the last hero drops digs in where they are, rather
	# than being deleted by the timing of the win.
	for w in walkers: _land_walker(w)
	walkers.clear()
	over = true; won = true
	chamber_won.emit()

func _defeat() -> void:
	if over: return
	over = true; won = false
	chamber_lost.emit()

## What the chamber is worth to the run.
func report() -> Dictionary:
	var paid := false
	for r in kill_lanes.keys():
		if not chucker_lanes.has(r): paid = true
	var board: Array = []
	for g in goblins:
		if g.hp <= 0.0: continue
		board.append({ "parts": g.parts.duplicate(), "col": g.col, "row": g.row,
			"age": g.age, "hp_frac": clampf(g.hp / g.max_hp(t, units), 0.15, 1.0) })
	return { "seen": seen.duplicate(), "deaths": goblin_deaths, "kills": killed,
		"paid_for_itself": paid, "traps": traps.duplicate(), "marches": marches,
		"veins": veins.duplicate(), "gold": coins, "board": board }
