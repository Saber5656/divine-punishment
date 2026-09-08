# Weather runtime verification — Issue 55

Godot 4.3 / macOS Apple M4, 2026-09-08. Main-agent implementation and self-review; no additional agent review calls.

- TDD: missing WeatherSystem/FootprintTrail initially failed; core rain modifiers, M8 900-second transition, spacing, expiry and ring capacity then passed.
- Boundary regressions failed for excluded-to-snow transitions and reduced spacing placing tracks behind the actor. Both corrected; 4 unit tests pass.
- Integration red/green covers real player footstep radius, guard view range and fragile lamps; runtime markers and friendly-track suppression also had missing-implementation failures before passing.
- Integration suite: 5 tests / 18 assertions pass, including actual guard movement through a synchronized navigation mesh toward a generated footprint.
- Full suite: 560 tests / 4605 assertions passed, exit 0, before the additional navigation test. No script/parse errors; existing headless dummy-renderer mesh and shutdown orphan warnings remain.
- Native Forward+ smoke: rain sound starts, rain/snow particles render, movement creates four marks, 90 seconds expires them, clearing stops precipitation; zero failures. Screenshots are technical fixtures, not final M6/M10 level artwork.

## Scope and review

Rain uses configured player-footstep and enemy-view multipliers. Fragile lights extinguish on rain and do not automatically relight. M8's canonical weather is RAIN_THEN_CLEAR and M10's is SNOW, correcting metadata introduced in #53.

Snow tracks retain at most 60 entries, sampled every 0.8 m by default, with simulation-time expiry after 90 seconds. Snow/soil/gravel accept tracks; wood, rock, logs, ice, water and airborne samples interrupt the trail. Sampling across an excluded boundary is deliberately conservative and starts a new segment. Player tracks become severity-1 anomalies; up to 32 guards leave visible friendly tracks without alerting their allies. Shared ring capacity includes both. Mission teardown resets weather; scene-owned visuals/audio are freed. M8's water-level gimmick belongs to its level issue and can subscribe to weather_changed.

Self-review checked event recursion, rain start ordering, temporary lamp state, bounds/lifetime/teleport handling, friendly self-detection, sound settings bus, mission lifecycle, and outgoing paths/secrets. No final campaign-level or human playtest completion is claimed.

Exported macOS PCK executed with the Godot 4.3 release binary: zero failures, four footprints, rain → snow → clear. Native release log contains no engine/script errors. Export itself retains the previously recorded development-only GUT loader warning; this did not occur during release execution. No release was published.
