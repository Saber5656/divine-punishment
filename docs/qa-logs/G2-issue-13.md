# G2 QA Log — Issue #13 Movement Validation Graybox

Status: headless Godot automation evidence recorded; rendered/manual inspection remains pending.

## Scope

Validate the asset-free Gym scene against the M1 movement routes and the floor-material sample contract.

## Automated evidence

- Scene: `src/levels/gym/movement_gym.tscn`
- Test: `tests/integration/test_movement_gym.gd`
- Covered routes: Ground/Crouch/Sprint, Hidden, Crawlspace, ClimbEdge → BeamPath → ClimbEdge, SwimSurface → SwimUnderwater → SwimSurface.
- Covered floor keys: `tatami`, `wood`, `creaky_wood`, `gravel`, `shallow_water`.
- Collision contract: graybox geometry uses world layer 1; gameplay markers use their existing marker scripts and layer constants.
- The main floor, sample walkway, and material panels form one continuous world-support route; the crawl endpoint is at `z=-5.5`, outside the water volume bounds (`z>=0`).
- Capsule clearance probes include a bounded 5 mm upward support tolerance, so a grounded foot contact is not misclassified as a crawl obstruction while ceiling and side blockers remain checked.
- The integration route keeps `PlayerController` physics enabled, crawls away from the inside endpoint for 30 physics frames and returns for 30 frames while asserting floor support, exits through the authored endpoint, and reaches the shallow-water material panel by live walking.
- Water entry is verified through `PlayerController._refresh_water_membership()` after moving into the authored volume; the test does not issue a second explicit `try_enter_water()` call.

## Interactive checklist

Run the procedure in [m00-movement-gym.md](../maps/m00-movement-gym.md) with Godot 4.3. The reviewer should record whether each route is reachable without clipping, whether the player can recover to the expected stance, and whether each material key is visible in the debug/noise instrumentation.

Headless Godot 4.3 validation passes all 192 tests in the local reproduction environment; rendered/manual inspection remains pending.
