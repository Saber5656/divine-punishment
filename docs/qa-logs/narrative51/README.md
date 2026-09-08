# Issue #51 narrative totals and text catalog

Main-agent self-review, Godot4.3, 2026-09-08.

Completed results carry a detached count snapshot. SaveManager accumulates non-target kills, civilian kills and detections, then computes shura from cumulative totals, so two detections in different missions produce one point. Existing result-screen save-once behavior prevents repeated display from accumulating again. Failed attempts/checkpoint retries retain the existing uncommitted-attempt behavior. GameState reads the saved values directly.

The existing v2 migration already contains these counters; it was reused and tested with nonzero v1 counts, original-data preservation and missing-field defaults. Legacy stored shura is preserved during migration, then recalculated from counters on the next completed result. No historical kills are fabricated from an old shura value.

Tool/mission display keys and remaining Japanese gym hints moved to CSV. Tool names resolve through `localized_name()` including the live inventory HUD. Legacy custom resource names remain valid. The displayed M2 target name was corrected from the old placeholder to the confirmed narrative name, 毒山刑部. This is a text consistency correction; actor IDs are unchanged.

Validation:
- Stats/save/formula tests failed before implementation; then2 tests/14 assertions passed.
- Localization API test failed before implementation; then1 test/6 assertions passed.
- Text lint was missing in the red run; both Python tests now pass, including literal/comment distinction and repository references.
- Integrated suite:531 tests/4352 assertions passed. Additional migration and GameState-view coverage brings the focused stats suite to4 tests/25 assertions, all passed.
- Actual exported PCK in the macOS release executable:zero failures; all five tool names resolve and the live HUD reads `1  小石  ×10`. No script/engine error in that native log. Existing headless dummy-renderer/ObjectDB shutdown warnings remain.

Self-review checked snapshot ownership, result-save gating, cumulative detection-pair rounding, v2 persistence, legacy fallback, CSV export translation fallback, static reference lint and source privacy. Numeric enum IDs and diagnostic values are not presented as translated player-facing prose. The CSV header stays `key,ja` because Godot requires a locale name for import; the loader exposes the requested key/text semantics.
