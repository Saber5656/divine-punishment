# M3 port layout validation (#170)

Scope: four collision layers, front/roof/water approaches, traversal markers,
observation positions and cover. NPC placement, objectives, final art and a
complete mission clear belong to #171–173, #61 and #60. `m03.level_scene` stays
unset until the playable mission is ready.

## Regression evidence

Godot 4.3, normal player capsule and movement controller:

- Missing scene test failed before construction. An initial parser failure was
  corrected and is not counted as a meaningful red test.
- Continuous ground capsule sweep found the stair entrance intersecting the
  third storehouse's north wall. Moving it to X=58 and aligning ramp floors
  made the sweep pass.
- Roof/ladder sweep checks the actual capsule through the roof opening and over
  every plank; it does not substitute a ray or a navigation position for passage.
- Rear shore test reproduced a swimmer stuck at X=85.55. The landing's swim
  boundary now ends before the rising bank. Additional channel coverage tests
  prevent this local cutout from removing water along the rest of the bank.
- A real reduced capsule enters the rear crawl marker and traverses to X=66.
- Observation/ladder checks failed before their markers/visual cues were added.

Native route runner: `tests/smoke/port_routes_smoke.tscn`, `--route=A|B|C` and
`--output-dir=<local evidence directory>`. It starts at the normal spawn, sends
movement and mapped interaction inputs, keeps collision/gravity active, and
records states, positions, timing, screenshots and failures. Held inputs are
reasserted each physics tick because a native window losing focus can release
synthetic input. No midpoint teleport, direct state assignment, or obstacle
removal is used. Test timeouts allow the slower swimming speed.

A reached the counting room in 32.368 s; B climbed the ladder/beam, dropped onto
the roof, crossed the bridge and reached the overhead position in 37.879 s.
C reached the below-target crawl position in the exported build in 121.235 s.
The final exported A/B times were 32.275 / 37.864 s, all with zero failures.
Recorded states: B = Climb → Beam → Ground; C = SwimSurface → SwimUnderwater
→ SwimSurface → Ground → Crawlspace. JSON results accompany the screenshots. These are developer automation times, not the
16-minute intermediate-player mission baseline or undetected clear evidence.

The final local suite passed 610 tests / 4,806 assertions; focused layout
checks passed 8 tests / 47 assertions. There were no script or parse errors. The headless renderer's existing
null-mesh/shutdown warnings are distinct from script/parse errors.

Pre-commit self-review checked layer collision masks, valid water contracts,
physical traversal rather than route metadata, acceptance scope, and private
paths/secrets. It also retained the discovered bank-coverage and crawl-porch
regressions. The rear ramp now has a supported low-end approach and a level
porch before the crawl entry; walking up a sloped marker with no porch had
failed the real posture transition even though a fixed-height sweep passed.

This is a graybox with original primitive geometry, not final art. Native
overview screenshots were visually checked. The 16-minute player baseline,
NPC detection/undetected clears and post-mission transition remain unverified.
