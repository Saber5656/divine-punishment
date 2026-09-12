# M4 campaign route validation (#181)

Godot 4.3 macOS release executable, Apple M4. Production base: `413980f`, following merged #180 / PR #185. The temple remains a graybox pending #63. This is developer automation with active AI, not a human playtest or final G3 approval.

## Exported normal-time routes

`tests/smoke/temple_clear_smoke.tscn` starts the actual campaign board with M4 unlocked in an isolated volatile save. It uses mapped movement, climbing, crawling, F assassination and E rescue/escape, with automatic heading steering. No actor placement, direct damage, disabled AI or accelerated clock is used. Run with `--route=A|B|C --output-dir=OUTPUT` from the project or an exported PCK with the Godot 4.3 release executable.

| Route | Elapsed wall time | Score | Detections / civilian / non-target kills | Outcome |
|---|---:|---:|---|---|
| A front steps and hall | 134.442 s | 75 | 0 / 0 / 0 | Back assassination and entry escape |
| B cliff, lodging roof and hall beam | 127.703 s | 75 | 0 / 0 / 0 | Above assassination, real checkpoint retry, entry escape |
| C stream, mill crawlspace and cell | 208.566 s | 80 | 0 / 0 / 0 | Both retainers freed and physically escaped, back assassination |

All three exports exited 0 with `failures: []`. Result JSON files retain stages, posture transitions, visibility, save flags and narrative. Maximum observed V was 0.491 or less. C uses surface swimming and preserves 20 seconds of breath. All runs unlock M5, preserve Shura 0 and store the correct first-clear side-objective outcome. The target corpse can be discovered; these runs do **not** claim the no-traces bonus. Saved H3 rendering and disk persistence are separately covered by [temple180](../temple180/README.md).

All routes displayed the exact authored inner line `……答えは、出ない。` and final words `同業よ……俺とお前の、何が違う`. The campaign Post cutscene is still #79 and was not displayed. `seen_cutscenes` therefore remains empty in these route records.

B's actual pause-menu retry replaced the scene in **212.040 ms**, restoring the dead target and post-assassination checkpoint at `(51, 11.9, 22.14842)`. The existing assassination releases traversal to **Ground** on the supporting board; retry restored that saved posture. An earlier fixture incorrectly expected Beam and failed despite correct restoration. Only that fixture assertion was corrected. A was run with the earlier driver; its production code and A inputs were unchanged, so its successful export is reused.

## Rain, lights, search and deadline

Six extinguishable lanterns sit under real roofs, verified by upward collision rays; two outdoor braziers stay lit in rain and cannot be extinguished. Each uses the existing 6 m light radius and 1.0 gameplay intensity. The visible bulb and OmniLight follow extinguish/relight events. Fourteen SearchPoints cover seven areas in pairs and lie within 0.25 m of actual ground navigation. Entry lies beyond every enemy's vision distance.

The integration test measures actual PlayerVisibility at the cell lantern before and after extinction. World checkpoint v2 preserves the exact eight light identities and states; incomplete payloads are rejected before mutation. This is an in-memory M4 world snapshot change, not a disk-save version change; old v1 M4 world snapshots are rejected.

The developer overlay at the roof approach reported all ten vision cones, eight light radii, zero active noise stimuli and V 0.030. All ten detection meters were zero. The full route counter checks and physical roof/light/nav assertions found no unfair detection on the exercised paths. This does not replace human readability evaluation after art integration.

`tests/smoke/temple_deadline_smoke.tscn` is a separate **8× clock and live-AI fixture** with the player untouched at entry and an inspection camera. At 719.067 s, both captives were alive. At 720.533 s, both were still alive while the two execution actors began walking. At 820.133 s, both captives had died after the actors reached the cell; only the side objective failed. The main target objective remained active throughout. Export exit 0, `failures: []`, 103.766 wall seconds. Bell diversion, +1 alert, actual gathering and deadline interruption reuse #180's unchanged integration and exported mechanics evidence.

TDD: missing environment contract first failed three tests; implemented environment passed **3 tests / 96 assertions**. Checkpoint regression **5/85**, objective regression **4/33**. Full local regression: **675 tests / 5,482 assertions**, no Script/Parse errors. Known headless dummy-renderer and shutdown warnings remain. Release runs contained no Script/Parse errors; use JSON and exit status because the release engine may leave its console log empty. Main-agent self-review covered production compatibility, driver claims, save isolation, physical invariants and private-data scanning.

## Per-level checklist (04 §4 and 07 appendix)

- [x] All three graybox routes complete undetected with active AI in the exported game.
- [x] Entry, terrace edges, gate pillars, hall corners, roof and cell approach provide observation/retreat positions; actual return routes are exercised.
- [x] Authored M4 ratio: six covered extinguishable lanterns and two outdoor persistent braziers (3:1); tuning is recorded in the map.
- [x] SearchPoints, routine stops and entry/court/cell/post-assassination checkpoints are placed and verified.
- [ ] Human baseline timing: 20-minute swift par remains an authored value; these automated times do not validate first-time/intermediate player timing (#49/#84).
- [x] Debug perception/light/noise inspection plus route counters on the paths above; final art readability still requires #63.
- [x] Safe first area exposes rain and water before enemy vision ranges.
- [x] A/B avoid the captive cell and all civilian kills; C safely rescues both.
- [ ] Inner/final words verified; authored Post transition/content remains #79.
- [x] Standard civilian +3/non-target +1 policy is inherited; these zero-kill exports preserve Shura 0.

#181 and parent #62 stay open for the unchecked acceptance items. #63 owns temple and actor presentation; #81 owns remaining H3 content/art. No release was published.

![Roof approach with live perception overlay](roof-perception.png)

![Actual rescue route result](rescue-result.png)

![Deadline after physical arrival at the cell](deadline.png)
