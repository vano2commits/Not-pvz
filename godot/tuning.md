# Every number in the game, in one place

Extracted from `prototype/hoard.html` so the port is copy-paste rather than
archaeology. Each row is `hoard.html` on the left, where it belongs in Godot on
the right. Nothing here has been run in Godot — see `PORT.md`.

## Board
| Value | Now | Godot home |
|---|---|---|
| `COLS, ROWS, CELL` | 7, 5, 96 | `BoardConfig.tres` |
| `OX, OY` | 96, 52 | `BoardConfig.tres` |
| `LANE_ORDER` | `[2,1,3,0,4]` | `BoardConfig.tres` |
| `lanesOpen(waveIx)` | `<3 → 3`, `<4 → 4`, else 5 | `BoardConfig.tres` curve |
| `laneBudget(waveIx)` | wave 1 → 1 lane, wave 2 → 2, then free | `BoardConfig.tres` |

## Economy
| Value | Now | Notes |
|---|---|---|
| `START_COINS` | 320 | swept; 250 left the player broke ~55% of a chamber |
| `yieldAt(col)` | `5 + col * 2.4` | the deeper-is-richer gradient |
| `DIG_EVERY` | 5s | seconds between payouts |
| `DIG_WARM` | 18s | to full output |
| `DIG_FLOOR` | 0.5 | what a fresh Digger pulls |
| `VEIN_PULLS` | 26 | payouts in one cell before it is dry |
| Rot purse multiplier | 2.6 | The Rot moves income to kills |
| Rot dig multiplier | 0.25 | |
| Tollkeeper cut | +1.6 per part | |

`VEIN_PULLS` is the load-bearing one. At 999 (infinite ground) six Diggers gave
a peak of 893 gold and the economy stopped mattering; at 26 six Diggers peak at
272 against three Diggers' 256, so spamming them stops paying.

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

## Heroes
| Hero | HP | Speed | DPS | Purse | Points | Trick |
|---|---|---|---|---|---|---|
| Squire | 150 | 22 | 22 | 14 | 1 | — |
| Scout | 150 | 42 | 16 | 13 | 2 | — |
| Sergeant | 520 | 18 | 30 | 30 | 2 | — |
| Leaper | 190 | 34 | 24 | 24 | 2 | vaults the first goblin |
| Pavise | 300 | 16 | 26 | 28 | 3 | soaks 14 off every hit |
| Runner | 90 | 58 | 12 | 10 | 1 | fast, fragile |

`hpScale = 1 + (chapter-1)*0.35 + (chamber-1)*0.12`

## Pacing
| Value | Now |
|---|---|
| Next wave trigger | current wave under 45% total HP — **skipped on the last wave** |
| Breath between waves | 2.2s |
| Wave spawn gap | `max(0.5, 1.6 - waveIx*0.17)` |
| Chambers per chapter | 3 |
| Waves per chamber | `min(6, 3 + chamber + (chapter-1))` |

## Meta
| Value | Now |
|---|---|
| Crew size | 5 foremen |
| Scrip per chamber | `1 + endGold/400` (~3 a chapter) |
| Bench | Sapper 14, Tollkeeper 14, Keg 16, Hollerer 22 |
| Kept on a loss | 30% of carried scrip |
| Upgrade offers | 3 after each cleared chamber |
