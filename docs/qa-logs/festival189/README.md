# M5 mission mechanics (#189)

## Fireworks foundation

A45second cycle masks all gameplay noise during its last3seconds and doubles visibility only at physical roof/bridge/beam surfaces. Ground, interiors and air remain neutral; hiding and crowd exclusion still win. Mission-owned providers unload with the scene. The population schedule is the production clock; pause freezes it, and restoring phase does not replay the boom mission event. Civilian screams still count for mission objectives while their sound is masked.

Core TDD:20tests74assertions passed after3intended behavior failures. Cycle/integration TDD:6tests74assertions passed after missing-provider/phase failures. Tests cover eight noise kinds, source-derived/direct dispatch, invalid effects, unload, transformed roof surfaces and pause. No Script/Parse errors in green logs.

Native Godot4.3/macOS fixture passed with explicit roof/ground player placements, disabled player motion and inspection camera, live population advanced40seconds. RoofV0.04→0.08duringburst→0.04after; groundV0.04; masked footstep suppressed and next ordinary footstep delivered. Pause froze42.4333seconds for30render frames. Original synthesized boom stream was playing; this confirms engine playback state, not a listening assessment. Screenshots were inspected for burst and readable Japanese countdown/hint. This is basic effect presentation pending65art/audio, not a full mission clear, G3 or human baseline.

Run `godot --path . res://tests/smoke/festival_fireworks_smoke.tscn -- --output-dir=<evidence-directory>`.

Main-agent self-review: effect lifetime belongs to the scene; no shared global flags; original dispatcher semantics retained outside masking; rooftop test uses transformed physical boxes and feet offset rather than global height; numeric bounds and restoration suppress duplicate events. Full mission objectives/checkpoints and final combined regression remain pending189integration.

## Objectives and lanterns

M5 now composes its real population, effects and objective scene. Target assassination enables southernEescape; successful escape grants the existing+5sidebonus only with zero civilian screams. A masked scream still removes that bonus without blocking main completion. The mission definition preserves20minutepar/civilian-heavy policy/fixedinner/finalwords and adds three naruko charges to its four-tool loadout. Sixteen persistent warm lanterns include two following actual crowds, plus14ground searchpoints. Prospective coordinates are in issue189instruction. Behavior TDD4tests5assertions failed before composition; implementation passes4tests96assertions in1.2seconds. Text catalog0findings. Main-agent self-review verified actual target signal routing, range/posture-gated escape, bonus once, masked-scream handling, nonextinguishable lights and crowd tracking. Checkpoint integration follows before publication.
