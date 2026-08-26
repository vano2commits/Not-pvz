## One kind of hero. Health is multiplied by the chamber's hp_scale at spawn.
class_name FoeDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var hp: int = 150
## Pixels a second, before any slow is applied.
@export var speed: float = 22.0
## Damage a second dealt to whatever it is chewing on.
@export var dps: float = 22.0
## Gold dropped on death, before a Coin-tipped shot or a Tollkeeper takes its cut.
@export var purse: int = 10
## How heavily this hero weighs on a lane when the spawner is choosing where to send
## the next one.
@export var points: int = 1

@export_group("Tricks")
## Hops the first goblin it meets, once, so a wall on its own stops being an answer.
@export var leaps: bool = false
## Flat damage shrugged off every hit, so chip damage stops working and you have to
## concentrate fire.
@export var soak: float = 0.0
## The Reeve. Sweeps the width of the board instead of walking a lane, and calls
## reinforcements into whichever lane you left emptiest. Bosses are also immune to
## bear traps — letting one delete the ending was a real bug in the prototype.
@export var boss: bool = false
