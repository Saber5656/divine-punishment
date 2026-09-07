# Issue #31: Player Death, Checkpoints, Retry

- Milestone: M4 / dependency: existing PlayerCombat (#28), SaveManager (#4), ToolInventory (#32), residence markers (#38).
- Base: f5c88d7 (2026-09-07). This is a prospective instruction, written before implementation.
- Gates: focused + full Godot 4.3 GUT, production-scene retry smoke and elapsed measurement.

## Objective and acceptance mapping

| Acceptance | Implementation | Evidence |
|---|---|---|
| Death presentation, retry/abandon choices | Player RetryFlow listens to Dead, freezes gameplay, fades overlay, exposes keyboard/controller buttons | FSM death, presentation and repeated-choice tests |
| CheckpointArea saves position/tool counts/area alert | Player-only mission-trigger Area3D, JSON-compatible bounded snapshot in GameState.checkpoint_ref | Real overlap, snapshot deep copy and restore tests |
| Retry within 3 seconds | Cached PackedScene reload resets dead FSM, enemies and transient scene objects; restores snapshot before unpausing | Residence production scene smoke, wall-clock result; hardware scope recorded |

## Sources and contracts

Read docs/02-game-design.md §6, docs/03-technical-design.md §5/7, docs/08-content-specs.md §5/10 and current PlayerCombat, ToolInventory, GameState and SaveManager.
Retain Dead's terminal FSM contract by creating a new Player rather than forcing a transition out of Dead. Add RetryFlow to player.tscn without renaming any existing child. CheckpointArea uses layer 15 and mask 2, ignores other bodies/dead players, exposes an editor collision gizmo. Existing residence checkpoint coordinates and IDs remain.

## Owned paths

New: src/player/player_retry_flow.gd, src/level/checkpoint_area.gd, src/core/checkpoint_snapshot.gd, retry tuning resource, abandonment UI, tests/unit/test_checkpoint_snapshot.gd, tests/integration/test_player_retry.gd and production-scene smoke. Update player.tscn, residence checkpoint factory/scene and docs/08 additive retry contract. No enemy AI/player movement modifications.

## Steps

1. Add pure snapshot validation/serialization for finite position/yaw, scene identity, tool slot IDs/counts, selected slot and bounded area alert.
2. Add CheckpointArea and wire three existing production markers. Spawn a real player in the residence scene. Establish an initial mission-entry checkpoint for death before first marker.
3. RetryFlow owns presentation/pause, guarded single transition, deferred new-scene restore, and elapsed measurement to the first playable physics frame. Retrying restores full health through normal new-instance initialization. The new scene clears temporary combat/tool effects.
4. Abandon exits to an actionable mission-abandoned screen; it clears only the in-memory checkpoint, never campaign/settings or persistent SaveManager data. SaveManager's version-2 disk checkpoint remains reserved for mission interruption; this issue does not add a disk write or migration.
5. Validate failure paths (missing/invalid checkpoint, foreign body, wrong scene, repeated request), count/alert isolation, actual area crossings, repeated death/retry and abandonment. Use isolated Godot user data for tests.

## Validation

Use GODOT_BIN pointing to verified 4.3.stable.official.77dcf97d8. Run headless import, focused GUT suites, scripts/run_tests.sh, and a standalone residence smoke that exercises the production death menu and scene replacement. Capture input tree, command, timings, passing counts and raw logs outside source. A headless measurement alone does not prove rendered timing; record rendered smoke separately when available. Exclude generated .godot/.uid/.import artifacts from commit.

## Out of scope

Disk save I/O/schema migration, general mission selection, enemy re-stealth (#30), art asset production, release and merge permission changes. Parent owns Vault, GitHub publication and CI integration.

## Integration with Issue #36

Parent-approved additive adapter: a `scene_director` group member may provide `retry_from_checkpoint(snapshot)->bool` and `show_mission_select()`. Prefer that route so Main remains persistent; retain standalone reload when absent. Resolve the mission by nearest scene ancestor, not Main. Snapshot restore remains RetryFlow-owned after mission child creation; the director must preserve the snapshot across MissionDirector initialization.
