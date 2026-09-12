# M3 port art and lighting validation (#61)

Godot 4.3, Blender 5.2.1 LTS, macOS release executable with the exported
`port61-normalized.pck` candidate. The kit has 14 original, metre-unit modules
and no external asset dependency. Screenshots below are inspection cameras;
full-clear evidence uses the actual unlocked campaign board and player camera.

![Quay, storehouses and dock workers](quay.png)
![Cargo sailing barge](ship.png)
![Counting house](house.png)

The physical, marker, navigation and gameplay-light snapshot is unchanged after
art builds. All six cargo solids are covered by 48 fitted crates, six existing
civilian bodies are dressed, and eight lamps follow extinction/relight state.
TDD caught duplicate-name coverage, opaque lamps blocking their own light,
missing worker models and nonidentity imported module transforms; these were
fixed before acceptance. One temporary GDScript type-inference error was also
fixed; its failed run is not counted as passing validation.

Validation: six asset-contract tests passed; focused art/lamp/civilian lifecycle
GUT 3 tests / 24 assertions passed after final mesh normalization. Full GUT
632 tests / 4,998 assertions passed before the final mesh-only normalization;
no script/parse errors. The final asset contracts and exported replays cover
that visual change. Main-agent self-review was used.

At 1440x900, four inspection views with live NPCs yielded 240 frame samples:
median 8.248ms, p95 9.525ms. Last-view rendering counters were 1,601 draw calls
and 440,176 primitives. This is a local inspection sample, not a worst-case
benchmark or cross-platform performance certification.

The controlled lighting comparison fixes the player/camera, freezes NPCs and
samples V plus the center image's luminance. It is separate from route testing:

| Case | V | Image luminance |
|---|---:|---:|
| Near pier lamp, on | 0.663758 | 0.228107 |
| Same position, off | 0.040000 | 0.187167 |
| Outside lamp range | 0.040000 | 0.184070 |
| Under solid counting floor | 0.012000 | 0.095943 |

The lamp visibly darkens when extinguished, and V falls with it. The overhead
lamp does not expose the crawlspace through the solid floor. These values
measure the tested cases, not every possible camera/occlusion combination.

All three exported routes passed via the actual unlocked campaign board, normal
mapped player input, active AI/perception/physics and normal time. The replay
never places an actor, calls a kill directly or grants invincibility. B consumes
two smoke bombs through mapped inventory/aim/throw input. C traverses the ship's
underwater clearance and the rear crawlspace before collecting the ledger.

| Route | Seconds | Detections | Civilian / non-target kills | Civilian screams |
|---|---:|---:|---:|---:|
| A | 108.599 | 0 | 0 / 0 | 3 |
| B | 85.723 | 0 | 0 / 0 | 1 |
| C | 292.639 | 0 | 0 / 0 | 0 |

Each reached the result screen with score 75 and the completed/one-strike/swift/
shadow-walker flags. No-traces and cargo side-objective were false; those are
not claimed by these routes. C finished without a civilian scream and retained
3.233 seconds of air at its lowest point. The saved result uses an isolated
in-memory store, not a new disk-persistence proof. The 16-minute authored par
and human baseline remain tracked separately in #173/#60.

Reproduce with a Godot 4.3 macOS release executable and an exported PCK. Run
`res://tests/smoke/port_art_smoke.tscn` for the four inspection cameras,
`res://tests/smoke/port_lighting_smoke.tscn` for controlled light comparisons,
and `res://tests/smoke/port_clear_smoke.tscn` with `-- --route=A|B|C` for gameplay.
Each accepts `--output-dir=...` and writes PNGs plus result.json; inspect the
process exit, failures array, reached screen and counters together. Do not
substitute an editor parse-success line for the replay results.
