## Naming and behaviour for fused bodies.
##
## Four parts make exactly 34 bodies, so all 34 are written down rather than generated.
## The generator this replaces stacked epithets to produce 119 names, which is where the
## "too many similarly named things" complaint comes from in merge games.
##
## Four parts also make six pairings, and every one of them does something. A body gets
## an interaction for every pair of kinds inside it, so a three-kind body gets all three
## at once — which is what gives all thirty mixed bodies a reason to exist rather than a
## name.
class_name Fusion
extends RefCounted

const BODY := {
	"barricade": "Barricade", "chucker": "Chucker", "digger": "Digger", "sapper": "Sapper",
	# two
	"barricade+barricade": "Bulwark", "barricade+chucker": "Loophole",
	"barricade+digger": "Strongbox", "barricade+sapper": "Shored Wall",
	"chucker+chucker": "Bowpair", "chucker+digger": "Coinsmith",
	"chucker+sapper": "Trencher", "digger+digger": "Deep Shaft",
	"digger+sapper": "Pit Crew", "sapper+sapper": "Spoil Crew",
	# three
	"barricade+barricade+barricade": "Great Wall", "barricade+barricade+chucker": "Redoubt",
	"barricade+barricade+digger": "Strongroom", "barricade+barricade+sapper": "Buttress",
	"barricade+chucker+chucker": "Gun Wall", "barricade+chucker+digger": "Countinghouse",
	"barricade+chucker+sapper": "Bastion Crew", "barricade+digger+digger": "Vault",
	"barricade+digger+sapper": "Shored Shaft", "barricade+sapper+sapper": "Dug-In Wall",
	"chucker+chucker+chucker": "Ballista Crew", "chucker+chucker+digger": "Payroll Guard",
	"chucker+chucker+sapper": "Skirmish Line", "chucker+digger+digger": "Assay Post",
	"chucker+digger+sapper": "Prospect Guard", "chucker+sapper+sapper": "Sap Line",
	"digger+digger+digger": "Delve", "digger+digger+sapper": "Deep Crew",
	"digger+sapper+sapper": "Tunnel Gang", "sapper+sapper+sapper": "Tunnel Crew",
}

## Every pair of kinds and what having both in one body does.
const PAIRS := [
	{ "a": "chucker", "b": "digger", "id": "tipped", "name": "Coin-tipped",
		"note": "Kills in its lane pay half again." },
	{ "a": "chucker", "b": "barricade", "id": "loophole", "name": "Loopholed",
		"note": "Takes a third less damage while it has a shot ready." },
	{ "a": "chucker", "b": "sapper", "id": "staggered", "name": "Staggering",
		"note": "Its shove interrupts, resetting what it hits." },
	{ "a": "digger", "b": "barricade", "id": "strongbox", "name": "Strongbox",
		"note": "Banks its take. Spills half of it when it dies." },
	{ "a": "digger", "b": "sapper", "id": "shored", "name": "Shored",
		"note": "Cannot be buried, and digs a quarter faster." },
	{ "a": "barricade", "b": "sapper", "id": "propped", "name": "Propped",
		"note": "Repairs itself when nothing is chewing on it." },
]

## The canonical key for a set of parts: sorted, joined with "+".
static func key_for(parts: Array) -> String:
	var sorted := parts.duplicate()
	sorted.sort()
	return "+".join(sorted)

static func name_for(parts: Array) -> String:
	var k := key_for(parts)
	if BODY.has(k):
		return BODY[k]
	# Unreachable with a four-part roster, but a body should never be nameless.
	return str(parts[0]).capitalize()

static func count_of(parts: Array, kind: String) -> int:
	var n := 0
	for p in parts:
		if p == kind:
			n += 1
	return n

static func has_pair(parts: Array, pair_id: String) -> bool:
	for pr in PAIRS:
		if pr["id"] == pair_id:
			return count_of(parts, pr["a"]) > 0 and count_of(parts, pr["b"]) > 0
	return false

## Every interaction active in this body, for the inspector panel.
static func pairs_in(parts: Array) -> Array:
	var out := []
	for pr in PAIRS:
		if count_of(parts, pr["a"]) > 0 and count_of(parts, pr["b"]) > 0:
			out.append(pr)
	return out

## How many bodies exist at all, for the ledger's "n of 34".
static func total_bodies() -> int:
	return BODY.size()
