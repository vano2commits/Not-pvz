# Moving Hoard to Godot

## Read this first

**No Godot code in this repo has been run.** Godot is not installed in the
environment I work in and `godotengine.org` is blocked by the network policy
here — only Godot 3 is reachable through apt, and Godot 3 GDScript differs
enough from Godot 4 that writing it would be worse than writing nothing. So
this is a plan and a data extraction, not a port. `tuning.md` is the part that
carries real value: every number, already swept, with its destination.

## Why now is the right time

The trigger was never code size — `hoard.html` is one file and will stay
manageable. It is that the next two things on the list are **numbers you want
to tweak without editing JavaScript** and **real art**, and those are exactly
what an engine buys. Everything before this point was faster to answer in HTML.

## What ports cleanly and what does not

**Ports as-is.** All the simulation. Wave tables, lane weighting, the fusion
rules, vein depletion, hero behaviour, the world rules, the upgrade effects —
this is plain logic and it maps to GDScript almost line for line. It is also
the part that has been measured, so keep the numbers and resist "improving"
them during the port.

**Rewrite, do not translate.** Everything drawing to canvas. `drawGoblin`,
`drawFoe`, the rubble and vein rendering, the particle system, the screen
shake — in Godot these become scenes, `AnimatedSprite2D`, `GPUParticles2D` and
a camera shake. Translating the canvas code would be fighting the engine.

**Throw away.** The Web Audio synth. It exists because artifacts cannot load
external files, and it is the reason the audio has been the weakest part all
along. In Godot you import files into an `AudioStreamPlayer` and the problem
disappears.

## A structure that keeps the numbers in the open

    res://data/          <- .tres resources, the whole of tuning.md
      units/*.tres         one per goblin: cost, hp, recharge, tint
      heroes/*.tres        one per hero: hp, speed, dps, purse, tricks
      worlds/*.tres        rule id, answer unit, tier
      upgrades/*.tres      the twelve run upgrades
      waves/*.tres         wave tables per chamber
    res://sim/           <- pure logic, no nodes, unit-testable
      board.gd  economy.gd  waves.gd  fusion.gd
    res://scenes/
      Chamber.tscn  Board.tscn  Goblin.tscn  Hero.tscn
      Warren.tscn  Muster.tscn  WorldSelect.tscn  UpgradePick.tscn
    res://tests/         <- GUT, mirroring the harnesses used here

Custom `Resource` classes with `@export` vars are the point: every number in
`tuning.md` becomes a field you edit in the inspector, which is the thing you
asked for.

## Order I would do it in

1. **Data layer + one chamber, no art.** Coloured rectangles. Get placement,
   fusion, waves and the economy running against the `.tres` files. If the
   numbers from `tuning.md` reproduce the same feel, the port is sound.
2. **Port the harnesses before the art.** The measurements in this repo —
   broke%, held%, diggers-vs-peak-gold, aliveAtEnd — are what caught every
   balance problem so far. In Godot they become GUT tests driving the sim
   headless. Do this *second*, not last, or the port silently changes balance.
3. **Meta layer.** Warren, muster, world select, upgrade pick. All plain UI.
4. **Art and audio.** The reason for the move.

## Things that will bite

- **Fixed timestep.** The browser build clamps `dt` to 0.05, which is what
  stops projectiles tunnelling through heroes. Use `_physics_process` and keep
  a hard cap on step size.
- **The foreman rule.** Upgrades and names attach to a *role*, not to a placed
  goblin. Model that explicitly or it will drift.
- **Board maths.** `OX/OY/CELL` are baked into hit-testing and drawing. In
  Godot use a `TileMapLayer` or a Node2D grid and let the engine own the
  transform; do not port the arithmetic.
- **Save data.** Currently `localStorage` under `hoard.v3`. Godot wants
  `user://` and a resource or JSON. Version the format from day one.

## What I would not port yet

`the-pour.html` and the older prototypes. The Pour is a good toy and it is not
in the loop; bring it over only if it earns a node type.
