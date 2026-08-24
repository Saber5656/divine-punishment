# Movement Validation Graybox (Gym)

`src/levels/gym/movement_gym.tscn` is a bounded, asset-free validation scene for the M1 movement stack. It is intentionally a graybox: the colored panels communicate the floor-material sample, while the marker scripts remain the gameplay contract.

## Stations

| Station | Scene path | Validation target |
|---|---|---|
| Open floor | `Geometry/MainFloor` | Ground, Crouch, and Sprint stance changes |
| Floor samples | `Geometry/FloorSamples/*` | `tatami`, `wood`, `creaky_wood`, `gravel`, `shallow_water` metadata |
| Climb + beam | `Markers/ClimbBeam` | `ClimbEdge → BeamPath → ClimbEdge` traversal |
| Crawlspace | `Markers/Crawlspace/CrawlEntrance` | Standing approach, crawl posture, and crouch exit |
| Water | `Markers/Water/WaterVolume` | Surface entry, underwater dive, and surfacing |
| Hide spot | `Markers/HideSpot/HideSpot` | Ground/Crouch entry to Hidden and Crouch exit |

The scene uses only Godot primitives and the existing player/marker scripts. No external assets are required.

## Layout contract

The root keeps the level-template containers from `docs/08-content-specs.md` §10.2 (`Geometry`, `NavigationRegion3D`, `Lights`, `Enemies`, `Civilians`, `Markers`, `Objectives`, `PlayerSpawn`, and `WeatherController`). The scene uses the world collision layer (`1`) for the graybox floor, wall, and crawl roof. Player and marker nodes use the layers defined in `docs/08-content-specs.md` §10.3; the scene does not introduce a new collision layer.

The graybox uses one continuous world-support floor under the stance, climb, crawl, water, and walkway routes. The sample walkway overlaps the main floor and each material panel by a small margin so a live physics walk cannot fall through a seam. Crawl and water are separated along `Z`; the crawl endpoint remains outside the water volume.

- The climb entry edge is at `(-3.5, 0, -3)`. Its top connects to the start of the 6 m beam at `(-3.5, 2.5, -3)`.
- The beam end connects to the exit edge at `(2.5, 2.5, -3)`, whose ground endpoint is `(2.5, 0, -3)`.
- The crawl entrance is at `(6, 0, -3)` and its floor-under endpoint is 2.5 m toward `-Z`; both endpoints are outside the water volume.
- The water volume is centered at `(8, 0, 3)`. Its body positions are bounded by the existing WaterVolume contract; underwater depth is 1.5 m so the supplied graybox floor remains clear of the player capsule.
- The hide spot is at `(0, 0, 4)` on the open floor.

## Manual validation procedure

1. Open `movement_gym.tscn` in Godot 4.3 and run the scene.
2. On the open floor, confirm the default Ground stance, toggle to Crouch, hold Sprint, and release Sprint to return to the previous stance.
3. Walk to the green climb marker, press `interact`, move forward to transfer onto the beam, and press Sprint to drop. Repeat from the far beam edge to verify the linked exit edge is visible in the gizmo.
4. Approach the crawl roof from the marked outside endpoint, press `interact`, crawl through, and press `interact` at the inside endpoint. Confirm the player returns to Crouch without clipping through the roof.
5. Enter the water station, toggle stance to dive, swim briefly, then toggle again to surface. Confirm the breath HUD and surface ripple presentation change with the state.
6. Approach the hide marker while Ground or Crouch, press `interact`, confirm Hidden removes the player from visibility calculations, then press `interact` to exit to Crouch.
7. Walk across each colored floor sample and record the material key shown by the future noise/debug overlay. The authored keys must remain exactly `tatami`, `wood`, `creaky_wood`, `gravel`, and `shallow_water`.

The automated integration test `tests/integration/test_movement_gym.gd` performs the scene-contract and route checks that do not require a rendered viewport.
