# Issue #36: Screen flow

Base: main `edc0ca9285fbb1d564ab54a43c06c64159485b7f`. Existing Main is a HUD-only shell (retrospective baseline).

Purpose: make title → select → play → results → select a usable loop, with pause/resume/retry/settings/abandon.

Read docs03 §7 (SceneDirector belongs under Main, not an autoload), docs09 §1–5/8/10 (Japanese text externalization and ink/vermilion styling), docs08 mission API. Depend on #35 objective events/results and #31 RetryFlow checkpoint APIs.

Ownership: src/ui/main.tscn, src/ui/scene_director.gd, data/text/ja.csv, data/missions/practice.tres, src/levels/gym/mission_flow_gym.{gd,tscn}, relevant screen-flow tests. Practice is a bounded replayable training arena using the existing production Player and TargetNpc, not the unfinished campaign/tutorial. Authored geometry stays in scene resources.

Acceptance mapping: all screens exercised through Main with a real target/escape objective; four pause actions preserve or discard only mission-local state; results show each scoring flag and a concrete next goal. Text is externalized. First-clear campaign persistence/full settings and story screens remain #37 and campaign Issues, not fabricated here.

Plan: Main owns SceneDirector and Mission child. Menus process while paused; remove/freeze Mission before changing screens; loading failure returns an actionable selection screen. Preserve existing HUD nodes. Register scene_director group for RetryFlow.retry_from_checkpoint and show_mission_select. Instantiate a fresh mission scene for retry, restore checkpoint after start_mission clears state. Do not overwrite disk saves during retry/abandon.

Integrate #37 SettingsController as a Main child and SettingsPanel inside a bounded Control host; configure the controller before entering the tree. Do not duplicate the settings implementation. Use existing asset-ledger title sample without new asset import.

Validation: focused scene routing, actual mission objective events, paused world freezing, resume/retry/abandon, result per-item text and next goal, invalid scene recovery; full Godot4.3 GUT after #31/#35 integration; rendered title/select/pause/results inspection; required PR GUT and main exports. Source SHA and results in canonical TSK1351. No new permissions/secrets/data deletion; normal review not required.

Parent-approved integration correction: production tests exposed that the old backstab pure predicate accepted targets behind the player's camera (+Z). Preserve the API argument frame and enemy-facing gate, correct the player's cone to standard -Z, update the old orientation fixtures, and add a real F-input mission regression. Do not camouflage the defect by rotating the player away from the target.

Parent-approved production scene correction: Perception must be Node3D so its EyePoint inherits the actor transform. With root at capsule center and standing feet -0.9, author enemy eye +0.7, target sphere +0.1, and meter +1.2. Prove translated/rotated eye transforms and actual crouched approach/F/escape.
