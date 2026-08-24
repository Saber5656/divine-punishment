# G2 QA Log — Issue #13 Movement Validation Graybox

Status: automation evidence recorded; interactive Godot run pending in this environment.

## Scope

Validate the asset-free Gym scene against the M1 movement routes and the floor-material sample contract.

## Automated evidence

- Scene: `src/levels/gym/movement_gym.tscn`
- Test: `tests/integration/test_movement_gym.gd`
- Covered routes: Ground/Crouch/Sprint, Hidden, Crawlspace, ClimbEdge → BeamPath → ClimbEdge, SwimSurface → SwimUnderwater → SwimSurface.
- Covered floor keys: `tatami`, `wood`, `creaky_wood`, `gravel`, `shallow_water`.
- Collision contract: graybox geometry uses world layer 1; gameplay markers use their existing marker scripts and layer constants.

## Interactive checklist

Run the procedure in [m00-movement-gym.md](../maps/m00-movement-gym.md) with Godot 4.3. The reviewer should record whether each route is reachable without clipping, whether the player can recover to the expected stance, and whether each material key is visible in the debug/noise instrumentation.

This checkout does not provide a `godot` executable, so the rendered/manual result is intentionally left pending rather than reported as a pass.
