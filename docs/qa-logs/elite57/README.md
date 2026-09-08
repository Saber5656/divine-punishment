# Enemy ninja verification — Issue 57

Godot4.3 / macOS Apple M4, 2026-09-08. Main-agent implementation/self-review without additional subagents.

TDD began with missing ninja-scene failures. The archetype loads the existing shinobi perception row (130-degree FOV, hearing1.5, dart immunity),4HP/1damage, dedicated navigation layer2 in addition to ground layer1, knockout immunity and zero-delay relight. Search tactics place at most3 caltrops per ninja/12 globally; traps last30 seconds, apply1 damage once to a player and use procedural geometry.

## Navigation findings and corrections

- An authored vertical link existed in the generated path, but resetting an unchanged target each frame restarted path progress. Both EnemyBase movement and EnemyBrain target updates now retain the path until the target changes.
- A first destination equal to Vector3.ZERO needs explicit path initialization; the new regression failed before the empty-path condition was added.
- Collision-free traversal passed, while the native floor fixture stayed at0.9m. Floor depenetration was incorrectly treated as excessive displacement; the movement bound now includes twice the1mm collision margin. Floor-backed regression then passed.
- A height-only native assertion accepted reaching the roof edge without reaching the destination. The final assertion checks destination distance. The initial20Hz deterministic roof test still passed; using actual60Hz steps reproduced edge blockage. The ninja agent now requires1mm waypoint proximity before leaving a vertical segment, preventing premature diagonal movement into the roof edge.
- Final native source smoke: destination reached within0.5m at height3.9m; ordinary guard stayed at0.9m. Bright detection gain0.05649 vs dark0.004824. One search caltrop; zero failures. The scene includes floor and roof collision shapes and runs actual Brain investigation.

Other tests cover immediate nearby relight, player displacement driving climb presentation, single-use trap damage/expiry, and ordinary guards excluding layer2. The earlier7-test suite passed20 assertions; strengthened roof checks and pose regression extend it. Early red/diagnostic logs remain evidence rather than being overwritten. Final full and exported results are appended below.

Self-review covered shared-navigation regression, initial origin target, finite bounded movement, per-world/per-agent trap limits, immunity on both actor/Brain paths, existing darkness formulas, and animation selection without changing collision transforms. The dedicated roof region/link must be authored with capsule clearance; ordinary ground regions remain layer1. This technical scene is not the final M7 level or artwork. Existing headless dummy-renderer/orphan and export-only development GUT warnings are retained as known limitations; no release publication or human test is claimed.

Final verification:579 tests/4660 assertions pass, exit0, no script/parse errors. Exported macOS PCK repeats the stronger roof-destination check: ninja(1.519981,3.9,0) within0.5m of(2,3.9,0), guard height0.9, bright/dark gains0.05649/0.004824, one caltrop, zero failures. Native release log has no engine/script errors. The roof screenshot was visually inspected. The first20Hz roof log named `roof-red` actually passed; the subsequent60Hz regression reproduced the failure before the1mm waypoint change.
