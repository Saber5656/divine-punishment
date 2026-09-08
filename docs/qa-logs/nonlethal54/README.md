# Non-lethal system validation

Main-agent implementation/self-review, Godot4.3, 2026-09-08. No delegation.

TDD reproduced forbidden kills completing objectives, missing policy aliases, wakeable/non-carryable restraints, missing player strike/rope actions, lethal public entry points, the missing M9 ratio, invalid contact counter acceptance, absent loadout application and absent automatic retry. Focused suites then passed. Initial full verification had3 failures: the new default action and12th player child needed contract updates, and input.knockout needed its catalog label. Corrected full run:551 passing tests/4567 assertions, exit0.

Self-review found upright incapacitated visuals. The first visual test omitted the adapter's deferred initialization and failed for that reason; after fixing the fixture, the old behavior correctly reproduced idle instead of knockout. Added a visual-only prone clip (existing Death01 motion, no lethal state) and Punch_Jab strike without a weapon. All4 focused action tests/22 assertions pass.

Native fixture uses the actual Player, EnemyBase, ToolRig, input action mapping, carry and SceneDirector retry. AI orientation is frozen to establish a reproducible rear approach. Input.parse_input_event did not reach the native callback in this environment even though the binding matched; Viewport.push_input routed the same physical G event through the game's input path and succeeded. Native result:0 failures, a living restrained body carried, rope consumed after2 seconds, and an injected forbidden-kill event recreated the mission from its checkpoint. This is system verification in a controlled fixture, not a completed M9 level or human playtest.

Checkpoint review preserves generic configurable knockout noise wake while the player strike explicitly disables it. Permanent restraints refuse manual/timed/noise wake. Added contact identity receipts prevent checkpoint retries from double-counting the same encounter. Known headless dummy-renderer/ObjectDB shutdown warnings remain.

Final complete suite after visual changes: exit0,552 passing tests/4569 assertions, no script errors. Python3 catalog tests pass. The native screenshot was visually inspected and shows the retained rope count, non-lethal controls and carried body. The fixture uses existing carry positioning; it is not final mission art.

Final exported macOS build repeated the physical-key viewport input, timed rope, living-body carry and checkpoint-retry sequence: exit0,0 failures, no engine/script errors. Self-review checked policy entry points, no-kill ordering, counter bounds, resource defaults, body/anomaly identity, visual/gameplay separation and private-path/secret hygiene.
