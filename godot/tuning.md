# Every number in the game, in one place

Extracted from `prototype/hoard.html` so the port is copy-paste rather than
archaeology. Each row is `hoard.html` on the left, where it belongs in Godot on
the right. Nothing here has been run in Godot — see `PORT.md`.

Where a number has a note, the note is why it is that number. Most of them were
swept rather than chosen, and the sweep result is the only reason to trust
them.

## Board
| Value | Now | Godot home |
|---|---|---|
| `COLS, ROWS, CELL` | 7, 5, 96 | `BoardConfig.tres` |
| `OX, OY` | 96, 52 | `BoardConfig.tres` |
| `LANE_ORDER` | `[2,1,3,0,4]` | `BoardConfig.tres` |
| `lanesOpen(waveIx)` | 3 lanes until wave 3, 4 until wave 4, then 5 | `BoardConfig.tres` curve |
| `laneBudget(waveIx)` | wave 1 → 1 lane, wave 2 → 2, then free | `BoardConfig.tres` |
| Tutorial gate | lane ramp runs **only in chapter 1, chamber 1** | — |

The lane ramp used to run at the top of every chapter, which meant sitting
through the tutorial four times a run.

## Economy
| Value | Now | Notes |
|---|---|---|
| `START_COINS` | 400 | opening gold is `400 × (1 + (chapter-1) × 0.2)` |
| `yieldAt(col)` | `3 + col × 1.5` | the deeper-is-richer gradient: 3 at col 0, 12 at col 6 |
| `DIG_EVERY` | 5s | seconds between payouts |
| `DIG_WARM` | 18s | to full output |
| `DIG_FLOOR` | 0.5 | what a fresh Digger pulls |
| `VEIN_PULLS` | 26 | payouts in one cell before it is dry |
| Tollkeeper cut | `+2.2 × n × (yieldAt(col)/RICH_MAX) × veinLeft` | scales with column, drains the same pocket |
| Tollkeeper vein bite | `(1/VEIN_PULLS) × n × bore × 0.55` | roughly 48 kills before dry |
| Carry between chambers | `endGold × 0.45 + 60` | |
| Scrip per chamber | `(1 + endGold/400) × chapter` | |
| Kept on a loss | 30% of carried scrip | |

`VEIN_PULLS` is the load-bearing one. At 999 (infinite ground) six Diggers gave
a peak of 893 gold and the economy stopped mattering; at 26 six Diggers peak at
272 against three Diggers' 256, so spamming them stops paying.

Opening gold rides `chamberMarkup`'s chapter term deliberately. When it rose
50% a chapter against a 25% price rise, chapter 4 opened with seven Chuckers'
worth against chapter 1's five — the deepest chapter started a third richer
than the first.

## Prices and scaling
| Value | Now |
|---|---|
| `chamberMarkup()` | `1 + (chamber-1) × 0.3 + (chapter-1) × 0.2` |
| `hpScale()` | `1 + (chapter-1) × 0.3 + (chamber-1) × 0.16` |
| `costOf(k)` | `max(15, base × cheap? × markup) − thrift × 8` |

More enemies per chamber was tried instead of a price rise and swept badly —
every wave multiplier drove chamber 3 to 0% held. It made the run unwinnable
rather than harder.

## Units
| Unit | Cost | HP | Recharge |
|---|---|---|---|
| Chucker | 70 | 120 | 6 |
| Digger | 50 | 95 | 6 |
| Barricade | 50 | 520 | 14 |
| Sapper | 75 | 150 | 9 |
| Tollkeeper | 75 | 110 | 9 |
| Powder Keg | 75 | 60 | 12 |
| Hollerer | 90 | 140 | 11 |

Fusion: `MAX_PARTS` 3, pooled HP × 0.72 for hybrids.

## The shot ladder
| Chuckers in the body | Cooldown | Damage | DPS/gold |
|---|---|---|---|
| 1 (no real Chucker: gravel) | 1.7 | 12 | — |
| 1 | 1.3 | 22 | 0.242 |
| 2 | 1.25 | 42 | 0.240 |
| 3 | 1.2 | 61 | 0.242 |

Flat on purpose. PvZ runs Peashooter and Repeater both at 0.140 damage/sec/sun
and Gatling at 0.125. An earlier build ran 0.242 → 0.551 → 0.714 and a single
stacked lane held everything by wave 4 of chapter 1.

Pierce comes **only** from the Ricochet upgrade. At 100 gold on a unit it
trivialised every wave.

## What each part adds to the shot
| Part | Effect |
|---|---|
| Powder Keg | `kind: bomb`, `aoe: 46 + 14n`, `aoeDmg: dmg × 0.55` |
| Hollerer | `slow: 1.1` (seconds of 0.62× speed) |
| Sapper | `shove: min(10, 4n)` px per hit |
| Tollkeeper | `bounty: 7n` gold |

Shove was 12px per Sapper. Against a squire's 28px of walking per shot cycle,
three Sappers drove heroes **backwards off the right edge** and never let them
cross at all.

## Slows
| Value | Now |
|---|---|
| Hollerer/Loud lane aura | 0.82× speed |
| Hollerer shot | 0.62× speed for 1.1s |
| Combination | `min(aura, shot)` — **not** the product |

These used to multiply, and Loud stacked the aura a second time. One 90-gold
Hollerer took a squire's crossing from 21 seconds to 93.

Reference crossing times, one unkillable squire over 460px:

| Body in the lane | Seconds |
|---|---|
| nothing | 20.9 |
| 1 Chucker | 29.0 |
| 1 Sapper | 33.2 |
| 1 Hollerer | 39.3 |
| Hollerer + Loud Chucker | 46.2 |
| 3 Sappers | 52.2 |

## Heroes
| Hero | HP | Speed | DPS | Purse | Points | Trick |
|---|---|---|---|---|---|---|
| Squire | 150 | 22 | 22 | 10 | 1 | — |
| Scout | 150 | 42 | 16 | 9 | 2 | — |
| Sergeant | 520 | 18 | 30 | 21 | 2 | armour |
| Leaper | 190 | 34 | 24 | 17 | 2 | vaults the first goblin |
| Pavise | 300 | 16 | 26 | 20 | 3 | soaks 14 off every hit |
| Runner | 90 | 58 | 12 | 7 | 1 | fast, fragile |

## Pacing
| Value | Now |
|---|---|
| Next wave trigger | current wave under 45% total HP — **skipped on the last wave** |
| Breath between waves | 2.2s |
| Wave spawn gap | `max(0.5, 1.6 − waveIx × 0.17)` |
| Chambers per chapter | 3 |
| Chapters per run | 4 |
| Waves per chamber | `min(6, 3 + chamber × 2 + (chapter−1))` |

Skipping the trigger on the last wave is not optional. Pulling the *next* wave
forward when there is no next wave fired victory before the field was clear.

## Worlds
Each world bends three economy numbers and nothing else. This table is the
whole of what makes a world different.

| World | Chapter | `purse` | `dig` | `bore` | Hazard |
|---|---|---|---|---|---|
| The Hollow | 1 | 1 | 1 | 1 | none |
| The Scree | 2 | 1 | 1 | 1 | rockfall buries a cell |
| The Rot | 3 | 1 | 0.25 | 1 | diggers pull a quarter |
| The Deep | 4 | 1 | 1.35 | 2.2 | no bear traps; 3-hit cart |

`bore` is the multiplier on how fast a pull eats the vein under it.

The Rot used to carry a flat `purse: 1.9` on top of the Tollkeeper multiplier
and a flat bounty — a squire worth 10 in the Scree was worth 110 in the Rot.
The Deep used to be numerically identical to the Scree, which is why it played
as the easy one: a rule that only costs you when you lose costs nothing while
you win.

## Scree
| Value | Now |
|---|---|
| `RUBBLE_LIFE` | 18s before a rockfall settles on its own |
| Rockfall interval | 12s |
| Max rubble at once | 3 cells |
| Sapper clears a lane cell | every 2.2s |
| Sapper digs **itself** out | 4.4s |

Rubble entombs rather than kills. Instant death from gravel was a dice roll. A
buried Sapper used to be frozen like anything else, which took the lane's
answer to rockfalls out of service for the full 18 seconds.

## The march
| Value | Now |
|---|---|
| `WALK_SPEED` | 118 px/s |
| Damage taken | full lane DPS while within `CELL × 0.55` of a hero |
| Destination dies mid-march | walker digs in at nearest open cell |
| Chamber ends mid-march | walker digs in |

Measured: a Digger crossing three Sergeants arrives with 15 of 95 health; six
Sergeants kill it.

## Meta
| Value | Now |
|---|---|
| Bench | Sapper 14, Tollkeeper 14, Keg 16, Hollerer 22 scrip |
| Minor upgrades (between chambers) | 4 offers, `base × (1 + owned × 0.7)`, bases 55–85 |
| Major upgrades (between chapters) | 3 offers, 640 role-specific / 780 universal |
| Gold at chapter end | wiped |
| Clear bonus | 20 scrip |

Bench roles are all obtainable free by reaching the chapter that owns them, so
scrip buys earliness, never power.
