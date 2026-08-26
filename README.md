# Hoard

A lane-defence game about goblins protecting a caravan of junk-treasure from
adventuring heroes.

You are not the gardener. You are the thing in the dungeon that the party is
coming to loot, and the five lanes running left across the screen are the
tunnel they are walking down to reach your pile of gold. Everything else
follows from that inversion: your units are cheap and expendable, your
"resource" is dug out of the ground rather than dropped from the sky, and the
things you kill drop purses.

It is a spiritual successor to *Plants vs Zombies 1* — not a clone. The grid,
the lane, the recharge timer and the cost-per-damage discipline are borrowed
deliberately. The upgrade system is not.

**Play it:** open `prototype/hoard.html` in a browser. No build step, no
dependencies, one file.

---

## Status

Playable end to end: four chapters, twelve chambers, seven unit roles, six
hero types, a hub, an in-run shop and a save file. Prototyped in a single HTML
file so that balance questions can be answered in minutes instead of hours.

Not done: audio is placeholder and unpleasant, art is coloured ellipses, and
nothing has been ported to Godot yet (see [Where it goes next](#where-it-goes-next)).

---

## The board

```
        col 0    1    2    3    4    5    6
      ┌─────┬────┬────┬────┬────┬────┬────┐
lane 0│     │    │    │    │    │    │    │  ← heroes enter from the right
lane 1│     │    │    │    │    │    │    │
lane 2│  T  │    │    │    │    │    │    │
lane 3│  H  │    │    │    │    │    │    │
lane 4│     │    │    │    │    │    │    │
      └─────┴────┴────┴────┴────┴────┴────┘
       caravan                    richer ground →
```

Seven columns, five lanes, 96px cells. Heroes walk right to left. If one
reaches the caravan you lose the chamber.

The board has a **gradient built into it**: `yieldAt(col) = 3 + col * 1.5`, so
a Digger on column 6 pulls 12 gold a payout and one on column 1 pulls 5. The
right-hand side of the board is where the money is *and* where the heroes
arrive first. Almost every interesting decision in the game is a position on
that gradient.

---

## The core loop: one chamber

1. Gold starts at 400. Nothing generates it but Diggers.
2. Place Diggers to the right for income, Chuckers to the left for damage,
   Barricades in between to buy time.
3. Waves arrive. Six of them, escalating, with the next wave pulled forward
   when the current one is nearly dead (PvZ's health trigger, so a competent
   player is never left waiting).
4. Veins run dry. `VEIN_PULLS = 26` payouts per cell, then that ground is
   worthless and the Digger standing on it is dead weight.
5. Hold all six waves and the chamber is yours.

Three chambers make a chapter. Within a chapter the board **persists** — your
survivors are still standing where you left them, at the health they survived
on, and 45% of your unspent gold carries over. A chapter is one continuous
defence broken into three sittings, not three fresh starts.

---

## Fusion is the whole game

There are only three units you can buy at the start, and everything else is
made by **dropping one goblin onto another**. A Chucker on a Chucker is a
Bowpair. A third makes a Ballista Crew. A Digger on a Chucker makes a
Coinsmith that shoots and mines.

Bodies hold three parts. That is the only cap.

### It is capability, not efficiency

This is the one place the design consciously refuses PvZ's answer. In PvZ,
Repeater and Gatling Pea are **separate purchases** that exist so you can
convert board space into damage — the Gatling is not more interesting than the
Repeater, it is the same thing in fewer tiles. That works in PvZ because
Survival mode makes tile-efficiency an actual constraint.

There is no survival mode here, so a "buy this unit to upgrade that unit" card
would be a card whose only text is *fewer tiles*. Instead every part brings its
own behaviour into whatever it joins:

| Part in the body | What the body's shot becomes |
|---|---|
| Powder Keg | shots become bombs with splash |
| Hollerer | shots slow whatever they hit |
| Sapper | shots shove heroes backwards |
| Tollkeeper | shots carry a bounty |
| Digger | the body also mines |
| Barricade | the body soaks far more |

So a Ballista Crew with a Keg in it is a mortar, and a Barricade with a
Tollkeeper in it is a tollbooth that will not move. **Fusion changes what a
tile does, not how many tiles you need.**

### Damage per gold is deliberately flat

| Body | DPS | Cost | DPS per gold |
|---|---|---|---|
| Chucker | 16.9 | 70 | 0.242 |
| Bowpair | 33.6 | 140 | 0.240 |
| Ballista Crew | 50.8 | 210 | 0.242 |

PvZ's line is the same shape — Peashooter and Repeater are both 0.140 damage
per second per sun, and Gatling is *worse* at 0.125. Buying up the ladder must
not be a raw efficiency gain, or the early game becomes a formality you click
through on the way to the real units. An earlier build had this curve running
0.242 → 0.551 → 0.714 and the game fell apart around wave four of chapter one:
a single stacked lane could hold everything.

Piercing shots are locked behind the Ricochet upgrade for the same reason. In
PvZ, pierce is rare and expensive; here it was briefly available for 100 gold
and trivialised every wave.

### Names

Fused bodies get generated names from their parts — 119 combinations, no
initials, no collisions. Pure stacks have their own ladder (Chucker → Bowpair →
Ballista Crew) and mixed bodies take an epithet from each ingredient (*Primed
Gilded Chucker* is a Chucker with a Keg and a Tollkeeper in it). The name is
shown on the cell before you commit the merge, so the trade is legible without
a tooltip.

### Merging is a march

Merging two goblins **already on the board** does not teleport one into the
other. It leaves its cell and walks the lanes on foot, and anything whose lane
it crosses gets a swing at it on the way.

```
clear road          arrives whole
3 Sergeants         arrives with 15 of 95 health
6 Sergeants         does not arrive
```

This exists so that recycling a spent Digger from column 6 is a decision about
the map rather than free tidying. If the destination dies mid-march, the walker
digs in at the nearest open cell instead of evaporating.

---

## The economy

Two ways to earn, and both are paid on the same geometry: **the further right
you stand, the more you make, and the sooner you get hit.**

**Digging** converts time into gold. A Digger pays every 5 seconds, ramps to
full output over 18 seconds, and each payout takes a bite out of the pocket
under its cell. Twenty-six pulls and the ground is dead.

**Tolling** converts kills into gold. A Tollkeeper takes a cut of everything
that dies in its lane, scaled by its column, drawn from the same pocket a
Digger would be draining:

```
                 gold from twelve squires, in order
no tollkeeper    10 10 10 10 10 10 10 10 10 10 10 10
at column 1      19 19 19 19 18 18 18 18 18 17 17 17
at column 6      32 32 31 31 30 30 29 29 28 28 27 27
```

Both taps run dry. That is the point — an economy that never stops mattering is
an economy you have to keep making decisions about. An early build had infinite
ground and six Diggers peaked at 893 gold; the constraint vanished by wave
three and the rest of the level was a formality.

---

## The units

Cost is the base price. Everything gets more expensive the deeper you go
(`×1.3` per chamber, `×1.2` per chapter).

| Unit | Cost | HP | Recharge | Does |
|---|---|---|---|---|
| **Chucker** | 70 | 120 | 6s | Throws rocks. The baseline. |
| **Digger** | 50 | 95 | 6s | Mines. Deeper is richer. |
| **Barricade** | 50 | 520 | 14s | Doesn't fight. Won't move. |
| **Sapper** | 75 | 150 | 9s | Clears rubble in its lane. Shots shove. |
| **Tollkeeper** | 75 | 110 | 9s | Takes a cut of kills in its lane. |
| **Powder Keg** | 75 | 60 | 12s | Blows up the lane. Once. |
| **Hollerer** | 90 | 140 | 11s | Jeers. Its lane slows down. |

## The heroes

| Hero | HP | Speed | DPS | Purse | Trick |
|---|---|---|---|---|---|
| Squire | 150 | 22 | 22 | 10 | the baseline |
| Scout | 150 | 42 | 16 | 9 | fast |
| Runner | 90 | 58 | 12 | 7 | very fast, very soft |
| Leaper | 190 | 34 | 24 | 17 | vaults the first wall it meets |
| Pavise | 300 | 16 | 26 | 20 | soaks 14 off every hit |
| Sergeant | 520 | 18 | 30 | 21 | armour |

Waves add one new thing at a time, the way PvZ 1-2 adds a Conehead rather than
a tougher Basic. Wave 1 is three squires in **one lane** — the first minute of
the game teaches the lane before it teaches anything else.

---

## The route

One line down. Four chapters, three chambers each.

| Chapter | World | Rule | Answer |
|---|---|---|---|
| 1 | **The Hollow** | Quiet ground. Nothing here but the heroes. | — |
| 2 | **The Scree** | Rockfall buries a cell every few seconds. You cannot build on rubble. | Sapper |
| 3 | **The Rot** | Dead ground. Diggers pull a quarter of what they should. | Tollkeeper |
| 4 | **The Deep** | Rich, thin seams, and no bear traps behind you. | Powder Keg |

Each chapter hands you its answer **the moment you arrive**, and that goblin
joins the crew mid-run. On a single line down you pack before you have seen
chapters two through four, so a local you could only use on the *next* run
would be a local you could never use where they matter.

### Every hazard has to be a running cost

This is the rule the worlds are built to, and it was learned the hard way. The
Rot and the Deep both played as the easy worlds, and measurement said why:

- **The Rot** compounded three multipliers on one corpse. A squire worth 10 in
  the Scree was worth 110 in the Rot with a Toll House watching — eleven times
  the money, for a hazard whose only ask was "stop using Diggers".
- **The Deep** was numerically *identical* to the Scree. A Digger pulled 64
  gold in either. Its rule ("no bear traps") only costs you anything when you
  are already losing, which means it costs nothing at all while you are
  winning.

Only the Scree charged rent every second you played. So the Deep's seams became
rich and thin — a pull is worth 1.35× and eats the vein 2.2× faster, so a Deep
Digger is something you keep having to *move* — and the Rot's multiplier was
folded entirely into the Tollkeeper.

A hazard the player can route around for free is not a hazard, it is a
sentence in a tooltip.

---

## Meta progression

Between runs you are in **the warren**. It has three jobs and fits on one
screen, because an earlier version was a hub with six screens and a
confirmation step on every action.

- **The route** — all four chapters and their rules, laid out as a map you read
  rather than a menu you pick from. Every run starts at the top.
- **The bench** — the only thing scrip buys. Sapper and Tollkeeper for 14,
  Powder Keg for 16, Hollerer for 22. All four are also *free* if you simply
  reach the chapter that owns them, so scrip buys **earliness**, never power.
- **Who lives here** — a quiet strip of the roster.

**Scrip** is the only thing that survives a run. You earn it by depth (deeper
chapters pay more per chamber) and you keep 30% of it if the cart is taken.
There is no grind currency and nothing on the bench makes you stronger — it
makes you *different sooner*.

### Inside a run

- **Between chambers:** a workbench with four small, cheap upgrades — +7 damage,
  +30% hide, −18% recharge, and so on. Bought with gold, priced up each time you
  buy the same one.
- **Between chapters:** the forge. Three expensive, fundamental upgrades
  (640–780 gold) that change how a role behaves rather than scaling it — Ricochet
  makes shots pierce, Quarryman trades rate for a landslide, Sling does the
  reverse, Prospector triples the first pull from fresh ground.
- Gold is **wiped** when a chapter ends. That is the one place it buys something
  permanent, which is why the forge is expensive on purpose.

The decision the meta is actually built around is **bank or go deeper**: at the
end of every chapter you can walk out with what you have carried, or descend
into a named, described, harder chapter. The screen tells you what is below
before you choose.

---

## Design decisions, and the things that were tried and cut

The reasoning matters more than the rules, so here is what was rejected and
why.

### Cut: PvZ-style upgrade units
An extra unit you carry solely to upgrade another one is a tile-efficiency
purchase, and tile efficiency is only a real constraint in a survival mode this
game does not have. Fusion replaced it. See [Fusion](#fusion-is-the-whole-game).

### Cut: a finite roster
A build (`prototype/muster.html`, kept on the branch) made goblins a finite
supply — you loaded a wagon, and anything that died was gone for the run. It
failed, and it failed for a structural reason worth recording: **the risk and
the reward were in different currencies with no exchange rate between them.**
You risked bodies and were paid in gold, and gold could not buy bodies. Every
risk was a permanent loss against an upside that never converted back.

Raising the unit count does not fix it. Either supply binds and every placement
is a small grief, or it does not bind and it is a number in the corner you stop
reading. There is no good value for that dial, because the dial was not the
problem.

The two mechanics worth keeping from it — the walking merge and the positional
Tollkeeper — were ported back into the main build and needed none of the roster
machinery.

### Cut: fog and the lantern
Fog worked in PvZ because the economy was slower and there were six lanes. Here
it was a tax you paid once and forgot. The Deep's identity became "no bear
traps" instead.

### Cut: rockfall that kills
Gravel landing on a unit and instantly killing it was not fun, it was a dice
roll. Rubble now **entombs** — the unit is still there, still soaks hits, but
stops working until it is dug out. A Sapper can dig *itself* out in 4.4
seconds, because one unlucky rockfall taking your answer to rockfalls out of
service for eighteen seconds with nothing to do about it is the same dice roll
wearing a hat.

### Cut: naming individual goblins
Scope creep. The warren keeps counts per role.

### Kept: waves can stack in one lane
PvZ spreads pressure because it has six lanes and slow sun; spreading is what
makes you build wide. Here, concentration is what makes you build *deep* — it
is the pressure that justifies a Ballista Crew existing instead of three
separate Chuckers. It is load-bearing for fusion, so it stays.

### Kept: runs are long
Thirty to forty minutes for a full descent. There was an argument for capping
run length for a mobile audience; it was rejected in favour of making a game
worth forty minutes.

### Everything is communicated visually
A rule the prototype is held to. The lane that is about to open caves in
visibly. Dead ground in the Rot is drained grey. A vein running out drains a
bar. A body that can accept the goblin in your hand is ringed with a plus. The
name of the fusion you are about to make is printed on the cell. If a mechanic
needs a paragraph of tutorial text, it is the mechanic that is wrong.

---

## How balance is done here

Not by feel. The prototype exposes its internals on `window.__hoard`, and
balance questions are answered by driving thousands of headless simulated
chambers in Playwright and reading the distribution.

Things that were caught this way and would not have been caught by playing:

- **Heroes were invisible** unless a goblin was on the board — a `globalAlpha`
  leak that reads back as `1` at frame end. Only pixel sampling found it.
- **Three Sappers pushed heroes backwards off the right edge of the board** and
  simply won. A shove was 12px per shot against 28px of walking.
- **One Hollerer took a hero's crossing from 21 seconds to 93**, because two
  separate slows were multiplying instead of taking the stronger.
- **Opening gold outran the shop.** It rose 50% a chapter while prices rose
  25%, so chapter 4 opened a third richer than chapter 1 while everything else
  about it was meant to be harder.
- **The "white flash" was never in the game at all.** 1558 instrumented frames
  found nothing; it was the browser's own tap-highlight painting over the
  canvas on every touch.

The lesson that keeps repeating: **sample the output, do not reason about the
state.** State assertions passed in every one of those cases.

Harnesses live outside the repo (they are throwaway), but the pattern is: load
the file, call `__hoard.begin({world, chapter, chamber, roles, upgrades})`, step
`__hoard.step(1/60)` in a loop, and read `__hoard.state`.

---

## Repo layout

```
godot/
  project/          ← the Godot 4 port. Open project.godot here.
  tools/gdcheck.mjs   static checker for the GDScript, since no Godot ran against it
  SETUP.md          ← opening it, where the numbers live, and the MCP toolkit
  PORT.md           the original port plan
  tuning.md         every tuned number with its destination
prototype/
  demo.html         ← the demo build the port was made from
  hoard.html        ← the full prototype
  muster.html       ← the finite-roster dead end, kept for reference
  veins.html        ← the chamber engine before the meta layer wrapped it
  descent.html      ← earlier: the run structure
  chamber-one.html  ← earlier: one level, proving the grid
  the-pour.html     ← earliest: does the premise read at all
  index.html
design/
  world-one.html    ← world one design doc
  progression.html  ← meta progression proposal
```

The older prototypes are kept deliberately. Each one answered a question, and
the answers are easier to re-read as running builds than as prose.

---

## Where it goes next

**Godot 4 — the port now exists**, in `godot/project`. Open `project.godot`, and every
number in the game is a field in `data/tuning.tres`. See `godot/SETUP.md`, which is
honest about the fact that no Godot has run against the code: it was written in a
container with no engine available, so expect first-open errors. `tools/gdcheck.mjs`
catches what can be caught without one.

The original reasoning, still true. The trigger is not code size — `hoard.html` is one file and will
stay manageable. It is that the next two things on the list are *numbers you
want to tweak without editing JavaScript* and *real art*, and those are exactly
what an engine buys.

`godot/tuning.md` carries every swept number with its destination, so the port
is copy-paste rather than archaeology. `godot/PORT.md` has the plan, including
an honest note that **no Godot code in this repository has been run** — Godot is
not available in the environment the prototype was built in.

Also outstanding:

- **Audio.** The oldest unaddressed complaint. Currently synthesised, electric
  and hard on the ears. Worth rebuilding in the engine rather than in
  `AudioContext`.
- **Hero readability.** The hero types are currently distinguished by speed and
  health more than by anything you can see. PvZ solved this with a traffic cone
  and a bucket; this needs its equivalent.
- **Chamber 3 composition.** The third chamber of a chapter still resolves
  itself if you have a ballista in every lane. Price and enemy count were both
  swept and neither is the answer — more enemies made it unwinnable rather than
  harder. The lever is composition: Sergeants and Pavises in the same wave, so
  that a line of ballistas stops being a complete answer.
