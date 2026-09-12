# M4 enemy placement and routine validation (#179)

Godot4.3, macOS AppleM4,1440×900. Existing character meshes and graybox geometry; bespoke monk/umbrella/naginata art remains#63.

## Evidence

- Generic shared-clock TDD:3missing-method failures, then3tests/24assertions pass; existing EnemyBrain18tests/107assertions pass. Combat, actor position and same-window dwell remain intact.
- Population TDD:5missing-scene failures, then5tests/65assertions pass. Private umbrella profiles give9.6m sight in actual rain; normal15m profile remains unchanged. Real target movement hall-to-cell and graveyard-to-court-to-ground pass.
- Full regression before the final audible cue:647tests/5153assertions. Added bell test:missing-cue failure, then1test/6assertions pass. No Script/Parse errors; known headless dummy-renderer null-mesh and shutdown warnings remain. Final CI covers the combined change.
- macOS release executable with exported final-audio PCK:96.100wallseconds at8× simulation speed;760.267simulationseconds,exit0,failures[]. Live brain/perception/collision remain enabled. Player stays at the normal start; inspection cameras are the only viewpoint override.
- At18.267s all eight monks have actually moved5.33–11.57m from their start. At3.2s and39.2s all eight face the hall with alignment dot≥0.99. Bell is playing at both chant samples and silent at18.267s.
- Tetsusenbo remains at(51,8.02,22) through719.2s and walks to(77.63774,5.120001,28.16239) by760.267s. The shared stop includes its end instant; inspection starts on the first tick after720s. No teleport or navigation-free movement is used.
- Rain particles and ambience are active in the exported replay. Separate normal-speed near-player inspection is recorded alongside this evidence.
- Review correction: campaign startup owns the sole weather presentation; standalone smoke scaffolding adds it explicitly. A real SceneDirector startup reproduced two emitters/audio players, then verified exactly one of each after the fix. The long AI replay predates this ownership-only refactor; actor schedules, movement, perception and bell code are unchanged.

## Reproduction

Run `tests/smoke/temple_population_smoke.tscn` with `--output-dir=OUTPUT`. The same scene runs from the exported PCK with the release executable. Add `--weather-only` for the2second normal-speed rain camera. Unit/integration tests use the normal GUT runner.

## Scope limits

This is an accelerated routine/presentation replay, not a stealth clear, rescue result, human timing baseline or campaign unlock proof. One-use gathering, execution party, captives, HP8/damage2 and checkpoint world state remain#180. Normal-time campaign E2E remains#181. No release was published.

![Shared sutra facing](sutra.png)

![Physical cell inspection](inspection.png)

![Normal-speed rain near the player](rain.png)
