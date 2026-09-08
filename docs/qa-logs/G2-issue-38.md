# Issue #38 tutorial validation

Implemented `m01` as a playable greybox tutorial: four production enemies, five teaching districts, eight ordered objectives, ground/roof exit routes, Japanese current-binding hints, checkpoints and results. Main mission selection exposes the mission and its saved best rank.

## Evidence and limits

Godot 4.3 stable official 77dcf97d8. The local wrapper supplies a macOS per-launch Cocoa option to avoid a stale-window restoration dialog; source/runtime binary is unchanged. Tests use the repository GUT command. The final validation record and complete raw logs are handed to the parent task for Agents Vault publication.

| Validation | Observation |
|---|---|
| Repository full suite | 474/474 tests, 3749 assertions, exit 0; 46.964 s GUT runtime. Headless dummy-renderer mesh warnings and one GUT orphan are retained in the raw log; no failing tests or script errors |
| TDD regressions | Missing visibility node, unearned shade lesson, missing physical noise investigation, checkpoint payload/storage, tutorial menu, and remap HUD regressions each have failing then passing focused logs |
| Fresh rendered ground route | `render-ground-21`: all eight learning records, actual PineCanopy occlusion, Crouch movement, moving patrol, peek, gravel noise, two stone impacts, two lamps, back assassination, body storage, document and results; 105.094 s, time_scale=1 |
| Fresh rendered roof route | `render-roof-final`: same mandatory learning, production climb and supported descent to results; 103.272 s, time_scale=1 |
| Result presentation | Both recorded `screen=results`; rendered Japanese result is score 100 / 皆伝 with zero non-target kills |
| Checkpoint isolation | Missing NPC payload is rejected before mutation; fresh mission state resets; dead target and storage owner restore without new kill credit |
| Settings re-entry | Actual SettingsController rebinding changes the HUD explanation when play resumes; tutorial uses the same InputMap helper |

The driver sends actual InputMap keyboard/mouse events and mouse-look motion, reads production movement/AI/results, and does not assign player positions during fresh runs. Debug runs explicitly marked `debug_checkpoint=true` restore a recorded checkpoint and are not counted as fresh complete-route evidence. The driver uses an in-memory result store to avoid overwriting personal saves; disk save behavior is covered by Issue #37.

The 5–10 minute first-play target is an estimate for reading, orientation and practice. The measured times above are an automated known route, not a measured first-time human play session. Geometry and character visuals remain greybox content; this validation does not claim final art, animation or broader campaign polish acceptance.

Observed fixes include an interaction overlap that re-extracted the stored corpse when collecting the document, a roof route blocked by the ground passage's tall side fence, and an unsafe unsupported descent. All were fixed in authored placement rather than bypassing production collision or marking objectives complete directly.

Unit checkpoint fixtures deliberately establish prior learning state to isolate restoration. They are not substituted for the separate fresh input runs. Initial source existed before the new TDD policy; resumed changes retain their actual red/green chronology.
