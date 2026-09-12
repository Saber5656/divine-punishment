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
| Near pier lamp, on | 0.663758 | 0.228108 |
| Same position, off | 0.040000 | 0.187165 |
| Outside lamp range | 0.040000 | 0.184193 |
| Under solid counting floor | 0.012000 | 0.095937 |

The lamp visibly darkens when extinguished, and V falls with it. The overhead
lamp does not expose the crawlspace through the solid floor. These values
measure the tested cases, not every possible camera/occlusion combination.

Exported route A and B have passed with active AI at normal time; final C replay
is pending at this revision. The final acceptance report will replace this
paragraph with all three route outcomes before closing #61.
