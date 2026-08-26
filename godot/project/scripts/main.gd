## The screen. Owns the simulation, the rack, the HUD and the between-chamber panels.
extends Control

@onready var board: BoardView = %Board
@onready var gold_label: Label = %Gold
@onready var wave_label: Label = %Wave
@onready var ground_label: Label = %Ground
@onready var banner: Label = %Banner
@onready var rack: HBoxContainer = %Rack
@onready var inspector: RichTextLabel = %Inspector
@onready var panel: PanelContainer = %Panel
@onready var panel_title: Label = %PanelTitle
@onready var panel_body: RichTextLabel = %PanelBody
@onready var panel_button: Button = %PanelButton

var sim: ChamberSim
var cards: Dictionary = {}          # unit id -> Button
var cooldowns: Dictionary = {}      # unit id -> seconds left
var banner_t: float = 0.0

func _ready() -> void:
	sim = ChamberSim.new(Game.t)
	board.sim = sim
	sim.chamber_won.connect(_on_chamber_end.bind(true))
	sim.chamber_lost.connect(_on_chamber_end.bind(false))
	sim.body_first_built.connect(_on_new_body)
	sim.wave_started.connect(_on_wave)
	sim.column_incoming.connect(_on_column)
	board.goblin_tapped.connect(_on_goblin_tapped)
	Run.begin()
	_show_panel("Hoard",
		"The heroes are coming down here for your gold. [b]Six chambers.[/b] "
		+ "Dig, throw rocks, and drop goblins on each other to make something worse.",
		"Down we go", _start_chamber)

func _start_chamber() -> void:
	panel.hide()
	sim.begin(Run.config())
	_build_rack()
	_flash("CHAMBER %d OF %d" % [Run.chamber, Game.CHAMBERS])

func _process(delta: float) -> void:
	if panel.visible or sim == null or sim.over:
		return
	sim.step(delta)
	for id in cooldowns:
		cooldowns[id] = maxf(0.0, cooldowns[id] - delta)
	if banner_t > 0.0:
		banner_t -= delta
		banner.modulate.a = clampf(banner_t, 0.0, 1.0)
		if banner_t <= 0.0: banner.hide()
	_refresh()

func _refresh() -> void:
	gold_label.text = "%d" % sim.coins
	wave_label.text = "—" if sim.wave_index < 0 else "%d/%d" % [
		sim.wave_index + 1, sim.waves.size()]
	ground_label.text = "%d cells · %d cracking" % [sim.usable_cells(), sim.cracking.size()]
	for id in cards:
		var b: Button = cards[id]
		var u: UnitDef = Game.units[id]
		b.disabled = sim.coins < u.cost or cooldowns.get(id, 0.0) > 0.0
		b.button_pressed = board.held_unit == id
		var cd: float = cooldowns.get(id, 0.0)
		b.text = "%s\n%d%s" % [u.display_name, u.cost,
			"" if cd <= 0.0 else "  %.0fs" % ceil(cd)]

func _build_rack() -> void:
	for c in rack.get_children(): c.queue_free()
	cards.clear(); cooldowns.clear()
	for id in Game.roster_for(Run.chamber):
		var u: UnitDef = Game.units[id]
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(120, 56)
		b.tooltip_text = u.blurb
		b.pressed.connect(_pick.bind(id))
		rack.add_child(b)
		cards[id] = b
		cooldowns[id] = 0.0

func _pick(id: String) -> void:
	board.held_unit = "" if board.held_unit == id else id
	board.selected = null

func _on_goblin_tapped(g: Goblin) -> void:
	if g == null:
		inspector.text = "[i]Tap a goblin to inspect it. Tap two to merge them — the first one walks.[/i]"
		return
	var lines: Array[String] = []
	lines.append("[b]%s[/b]  %d/%d hp" % [g.display_name(), int(g.hp),
		int(g.max_hp(Game.t, Game.units))])
	if g.parts.size() < Game.t.max_parts:
		lines.append("room for %d more" % (Game.t.max_parts - g.parts.size()))
	if g.banked > 0:
		lines.append("%d banked" % g.banked)
	# What this particular mixture does, named. Without this the only visible difference
	# between two fused bodies is the word on the cell.
	for pr in Fusion.pairs_in(g.parts):
		lines.append("[color=#8ed07a]%s[/color] %s" % [pr["name"], pr["note"]])
	inspector.text = "\n".join(lines)

func _on_new_body(g: Goblin) -> void:
	_flash(g.display_name().to_upper())

func _on_wave(_ix: int, wave_name: String) -> void:
	_flash(wave_name.to_upper())

func _on_column(lane: int, _seconds: float) -> void:
	_flash("THEY MASS IN LANE %d" % (lane + 1))

func _flash(text: String) -> void:
	banner.text = text
	banner.show()
	banner_t = 2.0

func _on_chamber_end(won: bool) -> void:
	var rep := sim.report()
	var more := Run.absorb(rep, won)
	if not more:
		_show_ending(won)
		return
	var lost := Run.lost_to_collapse
	var body := "Chamber %d held. " % (Run.chamber - 1)
	if lost > 0:
		body += "[color=#e0897a]%d goblin(s) went down with the floor.[/color] " % lost
	body += "\n\n%d cells left, %d of them cracking." % [
		Run.usable_cells(), Run.cracking.size()]
	_show_panel("Chamber %d held" % (Run.chamber - 1), body,
		"Into chamber %d" % Run.chamber, _start_chamber)

func _show_ending(won: bool) -> void:
	var lines: Array[String] = []
	lines.append("[b]%d[/b] of %d bodies built · [b]%d[/b] heroes stopped · [b]%d[/b] goblins lost"
		% [Run.seen.size(), Fusion.total_bodies(), Run.kills, Run.dead])
	var names: Array[String] = []
	for k in Run.seen: names.append(Fusion.BODY.get(k, k))
	names.sort()
	lines.append("\n" + ", ".join(names))
	if not Run.feats.is_empty():
		lines.append("\n[b]What you did[/b]")
		for f in Run.feats: lines.append("· " + str(f))
	lines.append("\nBelow this: [b]The Rot[/b], where the ground is dead and you earn "
		+ "off corpses instead, and [b]The Deep[/b], where the seams are rich and thin.")
	_show_panel("The hoard is still yours" if won else "They reached the caravan",
		"\n".join(lines), "Again", func():
			Run.begin()
			_start_chamber())

func _show_panel(title: String, body: String, action: String, cb: Callable) -> void:
	panel_title.text = title
	panel_body.text = body
	panel_button.text = action
	for c in panel_button.pressed.get_connections():
		panel_button.pressed.disconnect(c["callable"])
	panel_button.pressed.connect(cb)
	panel.show()
