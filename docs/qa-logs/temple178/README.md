# M4 rainy temple layout validation (#178)

The implementation follows the [pre-geometry map](../../maps/m04-rainy-temple.md).
It contains the front steps/gate/court/hall, cliff/graveyard/lodging roofs/beam,
and stream/watermill/cell crawlspace with a ground evacuation route. This is a
graybox: population, rain gameplay, bell, boss, rescue outcomes and campaign
integration remain #179–181; final environment art remains #63.

![Inspection camera showing the actual temple geometry](overview.png)

Final focused GUT: 7 tests / 66 assertions, including continuous real-capsule
clearance, swimming-to-bank transition, crawl entry/exit/step, and the existing
above-assassination prompt from the hall beam. No script/parse error; Godot's
headless dummy renderer emitted its known `Parameter "m" is null` messages.
The main agent reviewed and repaired the geometry before committing it.

MacOS Godot 4.3 release replays use mapped movement/E/C/Shift and actual
climb/beam/swim/crawl physics from the default spawn. There is no actor placement
or movement shortcut in the replay. No enemies are active in these layout runs;
the separate GUT prompt fixture adds one target for the overhead check. These
are not stealth clears, rescue outcomes, human baseline times or G3 acceptance.

| Route | Seconds | End posture | Scope |
|---|---:|---|---|
| A | 33.553 | Ground | Front steps to main hall |
| B | 36.559 | Beam | Cliff and lodging roof to hall beam |
| C | 121.118 | Ground | Stream, crawlspace, cell exit and evacuation to start |

All three processes exited 0 with empty failures arrays. A/B were repeated with
`temple178-checked.pck` after the final hall-roof/beam height correction. C uses
`temple178-final.pck`; that later correction does not change its geometry,
traversal or evacuation path, so its successful exported result is reused.
The final focused suite rechecks the shared contracts.

Failures were reproduced and fixed: overlapping cell stairs; a bridge reaching
the hall roof below its edge; water depth lock on the bank; a mill ramp projecting
into the landing; and a crawl exit capsule intersecting the first ramp incline.
The beam was lowered to stay within the existing 4m assassination range, with
no relaxation of the resolver or player collision checks.

Reproduce by exporting the project with Godot 4.3, then launch
`res://tests/smoke/temple_routes_smoke.tscn` with `-- --route=A|B|C` and an
`--output-dir=...`. Read the process exit, result.json failures, posture and
endpoint together. C includes the return to the introduction area.
