## One kind of goblin. Four of these make the demo's whole roster, and every fused
## body is some multiset of them.
class_name UnitDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## Gold to place. Cost is flat across the run — the board persists, so there is no
## per-chamber markup to tax a board you already own.
@export var cost: int = 50
## Health this part contributes to whatever body it joins.
@export var hp: int = 100
## Seconds before this card can be played again.
@export var recharge: float = 6.0
@export var tint: Color = Color("#6fbf5b")
@export_multiline var blurb: String = ""
## The world rule this unit is the answer to, if any. Empty for the starting three.
@export var answers: StringName = &""
