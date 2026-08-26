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

1. Godot 4.3 or newer. `project.godot` declares 4.3, so a newer editor will offer
   to convert it — that is expected and fine. Tested target is 4.7.
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

`godot_mcp_toolkit` runs on the machine with the editor and binds `127.0.0.1`. It cannot
be installed from the session that wrote this port — that is a cloud Linux container with
no Godot and no route to a desktop — so this part is yours to run. Everything below was
hit for real on Windows 11 with Godot 4.7, in this order.

### 1. Install the plugin by hand, not through AssetLib

There is no AssetLib tab in Godot 4.7. The old asset library is being replaced by the
Asset Store and the transition completes in 4.7, so the tab is simply gone. On 4.5 and
earlier it lives top-centre next to 2D / 3D / Script, and can also be hidden by
unticking it under **Editor → Manage Editor Features**.

Installing a plugin by hand works on every version and avoids the question:

1. Download the zip from the toolkit's asset page or its GitHub releases.
2. Extract it so you end up with `godot/project/addons/<plugin>/plugin.cfg`. If the zip
   wraps `addons/` in a top-level folder, drop the wrapper — `addons/` sits next to
   `project.godot`.
3. Reopen the project → **Project → Project Settings → Plugins** → Enable.

### 2. Install the bridge

Needs Node 22+.

```
npm install -g @npgamedev/godot-mcp-server
```

On Windows PowerShell this fails with `npm.ps1 cannot be loaded because running scripts
is disabled on this system`. That is PowerShell's execution policy blocking npm's
PowerShell shim, and it has nothing to do with the package. Call the batch shim instead
and nothing about the machine needs changing:

```
npm.cmd install -g @npgamedev/godot-mcp-server
```

The alternatives are running it from `cmd.exe`, or `Set-ExecutionPolicy -Scope
CurrentUser -ExecutionPolicy RemoteSigned` if you want npm to work normally in
PowerShell from then on.

### 3. Install Claude Code locally

The MCP bridge is only useful to a Claude Code running on the same machine as the
editor. A cloud session cannot reach a localhost bridge on your desktop, so this is a
separate install rather than something that carries over from the web app:

```
irm https://claude.ai/install.ps1 | iex
```

Restart the shell so `claude` is on PATH. The npm route
(`npm.cmd install -g @anthropic-ai/claude-code`) still works but is the legacy path and
does not self-update.

### 4. Wire them together

From `godot/project`:

```
claude mcp add godot -- godot-mcp-server
```

Restart Claude Code and check `/mcp` lists it. The editor must be open with the project
loaded.

Start with `GODOT_MCP_READ_ONLY=1`, which hides every mutating tool — let it read the
scene tree and the error list before you let it edit anything.

### None of this blocks opening the project

The toolkit is a convenience. The port is unrun code, and the fastest way to make it run
is to open `project.godot` and work through whatever the Debugger panel reports. Do that
first; the plugin can wait.
