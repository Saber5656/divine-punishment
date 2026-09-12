# M3 ledger, opium cargo and retry (#172)

The development mission requires Tokubei's death, nearby ledger pickup, then
physical presence at either the entry landing or rear water exit. E picks up
the ledger or carries/releases the opium crate. The crate must sink completely
below a real water volume to award the one-shot +5 side goal. Dropping it on
land or against the ship does not count. Cargo collision sweeps prevent the held
box from passing through storehouse walls. Unsupported carrying postures release
the box at its last supported hand position.

Checkpoint state includes the ordered objective, ledger, crate pose/velocity and
carried/disposed state, enemy AI/health and civilian life/pose. Restoration
validates the entire world before applying it and rejects objective/target,
ledger/objective or cargo/bonus disagreement. Rewinding revives actors without
emitting another death or retaining assassination/corpse flags. Entry, pier,
house approach and post-assassination checkpoints preserve this world state.
The pending checkpoint survives scene initialization before RetryFlow restores
its player and world.

## Evidence and limitations

- Missing objective data, missing cargo and missing world capture failed before
  implementation. Near pickup, ordered progress, physical exits, submerged
  disposal and score deduplication are integration tested.
- A pre-kill rewind reproduced the retained assassination lock, defeated flag
  and corpse collision layer. The lifecycle fix has its own isolated regression
  and commit. Fresh scene reload also reproduced erased progress / a restore
  error; initializing the mission before deferred retry and retaining the
  pending snapshot corrected it.
- A carried box reached X=76.3 through the storehouse wall before its shape sweep
  was added. Its regression now requires the box to remain before the wall.
- Native carrying fixture begins beside the opium crate, keeps NPCs/collision
  active, sends E, walks through the south door to open water and sends E again.
  A first route struck the ship hull and correctly earned no bonus; moving to
  open water north of the ship completed disposal in 7.88 s before the final
  hand-collision repair. The final exported run, including the hand-collision repair, passed in
  7.872 s; cargo center (82.69803, -1.366343, 40.93857), bonus recorded once.
- Native retry fixture uses direct target death / initial position to isolate
  E pickup, the production SceneDirector/RetryFlow scene replacement and the
  result UI. It restored objective index 2 and reached results, failures 0;
  source retry measured 82.376 ms; the final exported run measured 69.698 ms,
  restored position (68, 3.000019, 13.2), and reached results with zero failures.
  A volatile store avoids changing campaign saves.
- Those fixtures are not full routes, actual F assassination, human timing or
  undetected clear evidence. Campaign entry stays disabled until #173 validates
  the complete mission. Post-cutscene acceptance remains dependent on #79.

The ledger/interaction wording uses the Japanese text catalog and existing font.
This is native Godot graybox UI, not a Web/mobile redesign. Final art and sound
remain in #61/#82. Existing headless null-mesh/shutdown warnings are distinguished
from script/parse failures; failed parser iterations are retained in raw logs
and never counted as successful tests.

## Final checks

Godot 4.3: 623 tests / 4,895 assertions passed in the full suite; no script or
parse errors. Focused objective checks: 8 tests / 62 assertions. NPC lifecycle
regression: 1 test / 10 assertions. Japanese catalog checks: 3 passed. An earlier
full run exposed alarm state leaking between test fixtures; the population
fixture now saves/restores its initial alarm and objective fixtures clean up
mission globals. Production AI was not disabled to make those tests pass.

Main-agent self-review covered ordered objectives, physical reach/line of sight,
water-only reward, complete validation before restoration, lifecycle flags,
scene-replacement ordering, fixture limitations and private-path/secret hygiene.
The exported fixtures and screenshots are retained in the private task evidence;
the native graybox is not final artwork or a published release.
