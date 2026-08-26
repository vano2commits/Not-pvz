# Opening the Godot project

## Read this first

**No Godot has run against this code.** It was written in a cloud Linux container with
no Godot binary, no access to `godotengine.org` (the egress proxy returns 403), and only
Godot 3.5 in apt — a major version too old to be worth anything here. So the port is
written, checked statically, and unrun.

What that means in practice: expect a handful of first-open errors of the kind a compiler
catches instantly and a human never spots by reading. `tools/gdcheck.mjs` catches the
classes of mistake I could catch without an engine — unbalanced brackets, mixed
indentation, Godot 3 API, calls to methods that do not exist, `%UniqueName` references
with no matching node, `.tres` files pointing at the wrong `class_name`, and autoload
names that collide with a `class_name`. It found four real bugs while this was being
written, including `Tuning` being used as both an autoload and a class name, which Godot
rejects outright.

Run it any time:

```
node tools/gdcheck.mjs project
```

## Open it

1. Godot 4.3 or newer. Yours is at
   `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine`.
2. **Import** → pick `godot/project/project.godot`.
3. Let it import. F5 to run.

If something fails on first open, the fastest fix loop is the error list in the editor's
Debugger panel — every one of them will name a file and a line.

## Where the numbers live

`data/tuning.tres`. Open it in the inspector and every value in the game is a field,
grouped: Board, Economy, Fusion, Pacing, Collapsing ground, The Scree, Combat. This is
the entire reason the project moved off a single HTML file — changing a number no longer
means editing code, and the comment on each one says why it is that number. Most were
swept rather than chosen.

Units, heroes and worlds are one `.tres` each under `data/`. Adding a hero is a new
resource plus a line in `game.gd`'s preload list; adding a world is the same.

## Shape of the code

```
scripts/
  tuning.gd        every tunable number, as @export fields
  unit_def.gd      one kind of goblin
  foe_def.gd       one kind of hero
  world_def.gd     a world bends three economy numbers and adds one hazard
  fusion.gd        the 34 named bodies and the six pair interactions
  goblin.gd        one body on the board
  foe.gd           one hero walking left
  chamber_sim.gd   THE FIGHT. No Node, no drawing, no input.
  run.gd           autoload. six chambers, persistence, the collapsing ground
  game.gd          autoload. loads the resources, answers "what is in chamber N"
  board_view.gd    immediate-mode drawing and taps
  main.gd          the screen: HUD, rack, inspector, panels
```

`chamber_sim.gd` never touches the scene tree. That is deliberate and worth keeping:
the prototype's balance work was only possible because the simulation could be stepped
thousands of times faster than real time by a harness. The same is true here — a
headless test can `ChamberSim.new(tuning)`, `begin(cfg)`, and loop `step(1.0/60.0)`
without a window. Everything that needs to be true about the game should be checkable
that way.

## What is ported and what is not

**Ported.** The board and its gradient, the economy and vein depletion, the richness
that rises as ground is lost, all four units, all seven heroes, the flat damage ladder,
fusion with all 34 named bodies, all six pair interactions, the march, rockfall and
Sapper dig-out, bear traps as a one-off for the run, the wave table, the column wave and
its warning, the Reeve's sweep and its reinforcements, boss trap-immunity, the persistent
board, the collapse schedule with both guard rules, feats, and the ledger count.

**Not ported yet.** Audio (the Web Audio synth needs rebuilding as an `AudioStreamPlayer`
bank — the constraint that produced it is gone, so use real samples). Particles, screen
shake and the hit-stop. Route cards between chambers 2 and 4. Drag-to-place. The mobile
layout. None of these are load-bearing for checking that the simulation ported correctly,
which is the first thing worth doing.

## The MCP toolkit

`godot_mcp_toolkit` runs on the machine with the editor, and binds `127.0.0.1`. It cannot
be installed from this session — that container is a cloud Linux VM with no Godot and no
route to your desktop — so this part is yours to run:

1. In Godot: **AssetLib** → search "Godot MCP Toolkit" → Download → Install, then
   **Project → Project Settings → Plugins** → enable it.
2. In a terminal (needs Node.js 22 or newer):
   ```
   npm install -g @npgamedev/godot-mcp-server
   ```
3. Register it with your local Claude Code, from the project folder:
   ```
   claude mcp add godot -- godot-mcp-server
   ```
4. Restart Claude Code and check `/mcp` lists it. The editor must be open with the
   project loaded for the tools to connect.

Two things worth knowing before you turn it on. `GODOT_MCP_READ_ONLY=1` hides every
mutating tool, which is the setting to start with — let it read the scene tree and the
errors before you let it edit anything. And it is only useful to a Claude Code running on
your machine; a cloud session like this one cannot reach a localhost bridge on your
desktop, so pointing this session at it will not work.

Sources for the above: the toolkit's Asset Library page and its server package.
