## One body on the board. A goblin is a multiset of parts plus a cell, and everything
## it does falls out of what it is made of.
class_name Goblin
extends RefCounted

var id: int = 0
var parts: Array[String] = []
var col: int = 0
var row: int = 0
var hp: float = 0.0

## Seconds until it can shoot again, and until it can pull again.
var cooldown: float = 0.5
var dig_cooldown: float = 1.2
## Seconds until a Sapper in this body shovels its lane again.
var sapper_cd: float = 0.0
## Seconds it has been digging, which is what warms the shaft up.
var age: float = 0.0
## Gold a Strongbox is sitting on. Spills when it dies.
var banked: int = 0

var born: float = 0.0
var last_hit: float = -99.0
var entombed: bool = false
var dug_out: float = 0.0
var mourned: bool = false

# presentation only
var squash: float = 0.0
var land: float = 0.0
var recoil: float = 0.0
var hurt: float = 0.0
var wind: float = 0.0

func key() -> String:
	return Fusion.key_for(parts)

func display_name() -> String:
	return Fusion.name_for(parts)

func count_of(kind: String) -> int:
	return Fusion.count_of(parts, kind)

func has_pair(pair_id: String) -> bool:
	return Fusion.has_pair(parts, pair_id)

func max_hp(t: Tuning, units: Dictionary) -> float:
	var total := 0.0
	for p in parts:
		total += float(units[p].hp)
	if parts.size() > 1:
		total *= t.hybrid_hp
	return total

func spent(units: Dictionary) -> int:
	var total := 0
	for p in parts:
		total += units[p].cost
	return total
