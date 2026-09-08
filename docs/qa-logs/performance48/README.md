# Production performance measurement

Godot 4.3, native Forward+ Vulkan renderer, Apple M4, 2026-09-08. Render target verified as 1920×1080; VSync disabled. This is an actual hardware measurement, not a headless FPS estimate or a benchmark of a discrete Windows GPU.

`tests/smoke/production_performance_smoke.tscn` loads the baked residence, supplements its population to 12 enemies and 20 dynamically shadowed LightSources, and samples three cameras. Each view warms for 120 frames and records 300 rendered frame intervals. The player receives temporary damage immunity in this fixture so enemy AI and perception remain active. No enemy brain is disabled. Frame time includes native scheduling and rendering; perception measures tick, noise and anomaly callbacks, including their synchronous dispatch cost. Final instrumentation also includes player visibility/light queries; it does not count the whole enemy brain as perception.

## Findings and recovery

The first exploratory run lost its player during measurement; perception calls eventually reached zero, so that run is invalid as acceptance evidence. A fixture path typo in the immunity setup was corrected before the active-load run.

The valid pre-optimization run reported mean frame times 15.320 / 14.459 / 8.336 ms; p95 16.622 / 15.976 / 9.167 ms. Perception p95 was 0.754 / 0.751 / 0.731 ms, with maxima 0.811 / 1.133 / 0.854 ms.

Self-review found repeated scanning of exhausted anomaly groups. The old 64-node budget visited just 32 unique markers when alternating a large marker group with one enemy. TDD reproduced this; the corrected scan spends the budget on 63 distinct markers plus the observer, keeps the cap, and preserves group rotation. Normal gameplay never enables timing collection; opt-in recording caps at 60000 frames and is reset by the fixture.

Final measurements and validation follow below. Reproduce with the native Godot 4.3 editor or an exported PCK containing this smoke scene. Do not run other heavy tests/bakes concurrently with the capture.

## Exported release result and remaining acceptance

Final exported PCK, same Godot 4.3 release executable, active player throughout, 300 frames per view:

| View | Mean ms | p95 ms | Max ms | Perception p95 ms | Perception max ms | Draw calls |
|---|---:|---:|---:|---:|---:|---:|
| Overview | 14.739 | 16.079 | 28.737 | 0.705 | 1.859 | 910 |
| Garden | 15.441 | 16.776 | 36.732 | 0.701 | 1.813 | 1066 |
| Interior | 8.334 | 9.231 | 9.450 | 0.689 | 0.788 | 191 |

The final capture includes player light/visibility queries. Perception is summed by render frame using wall-clock measurements, so callback dispatch, scheduling and multiple physics updates in a delayed render frame are included. Do not reinterpret the maximum as exclusively CPU execution time or discard the outliers. Earlier enemy-only optimized maxima were 0.749/0.768/0.776 ms; they are not the final full-scope acceptance numbers.

Distant residence lamps now fade shadows beyond three gameplay radii and light energy beyond four radii, over two radii. Nearby gameplay illumination/ranges are unchanged. This reduced overview draw calls from 1189 in the first exported run to 910. The regression for enabled distance fading failed before implementation and passed afterward (68 assertions).

**Issue #48 remains open.** Average frame rates exceed 60 on this Apple M4, but garden p95 slightly exceeds 16.667 ms and full-scope perception has >1 ms spikes. A sustained target-hardware run and further profiling/optimization are still needed before strict acceptance; no unmeasured GPU equivalence is claimed.

Validation: 525 tests / 4317 assertions passed before the final light-distance change; the affected lighting test then passed 68 assertions. TDD also covers opt-in profiling (7 assertions), fair bounded scanning and inclusion of player visibility queries. The exported native scene loaded and kept all 12 enemies, 20 lights and the live player through all views. Self-reviewed before commit. Full CI will verify the final diff.

Final exported lighting regression: zero failures. Near-on V 0.561396/luminance 0.138596, off V 0.04/luminance 0.053700, far V 0.04 and under-floor V 0.012. The distance optimization preserves the near-camera lighting/stealth correspondence.
