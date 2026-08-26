## A world bends three economy numbers and adds one hazard. That is the whole of what
## makes one different from another, and keeping it to three fields is deliberate: a
## hazard the player can route around for free is a sentence in a tooltip.
class_name WorldDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var rule: String = ""
@export_multiline var fix: String = ""
## The unit this world hands you on arrival.
@export var answer: StringName = &""

@export_group("Economy")
## What a dead hero is worth here.
@export var purse_mult: float = 1.0
## What a pull out of a vein is worth here.
@export var dig_mult: float = 1.0
## How fast a pull eats the seam under it.
@export var bore_mult: float = 1.0

@export_group("Hazards")
## Rockfall buries a cell every few seconds. The Scree.
@export var rockfall: bool = false
## Bear traps behind the line. Off in The Deep, where nothing catches a leak.
@export var bear_traps: bool = true
