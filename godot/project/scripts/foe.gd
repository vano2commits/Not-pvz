## One hero walking left. Everything except the Reeve stays in the lane it entered.
class_name Foe
extends RefCounted

var kind: String = "squire"
var lane: int = 2
## Drawn lane, which lags `lane` so the Reeve's sweep is visible rather than a jump.
var lane_f: float = 2.0
var x: float = 0.0
var hp: float = 0.0
var max_hp: float = 0.0
var speed: float = 22.0

var slow_for: float = 0.0
var stun_for: float = 0.0
var hit_flash: float = 0.0
var bleeding: bool = false
var bob: float = 0.0
var squash: float = 0.0
var dead: bool = false
var by_trap: bool = false

## Set by the shot that is about to land, so the purse knows what killed it.
var tipped: bool = false
var bounty: int = 0

# Leaper
var leapt: bool = false
var vault: float = -1.0
var vault_from: float = 0.0
var vault_to: float = 0.0

# The Reeve
var sweep_t: float = 2.2
var sweep_dir: int = 1
var call_t: float = 6.0
