## What arrives, and in what order. One new thing per wave, the way PvZ 1-2 adds a
## Conehead rather than a tougher Basic.
class_name WaveTable
extends RefCounted

const S := "squire"
const C := "scout"
const G := "sergeant"
const R := "runner"
const B := "reeve"

const WAVES := [
	{ "name": "First light",  "list": [S, S, S] },
	{ "name": "They regroup", "list": [S, S, S, S, S] },
	{ "name": "Outriders",    "list": [S, S, S, S, S, S, S] },
	{ "name": "Fast ones",    "list": [S, S, C, S, S, C, S, C, S, S] },
	{ "name": "Armour up",    "list": [S, C, S, G, S, S, C, G, S, C, S, S, G, C] },
	{ "name": "Last of them", "list": [G, S, C, G, S, S, C, S, G, S, C, S, G, S, C, S, G, C, G, S, C, G, S, G] },
]

## A column, not a crowd. Front-loaded single-target damage kills the front rank very
## well and the queue behind it keeps walking, so the answer is anything that reaches
## past it — splash, a shove, a slow, or a wall bought with what a Digger earned. Every
## one of those is a body made of more than one kind of goblin.
const COLUMN := { "name": "Down one throat", "stack": 1,
	"list": [S, G, S, S, G, S, G, S, S, G, S, G] }

const BOSS := { "name": "The Reeve", "list": [B] }
