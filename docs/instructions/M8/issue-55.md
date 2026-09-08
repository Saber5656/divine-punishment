# Issue 55 — Weather

Rain/snow modifiers and presentation are mission-owned and use WeatherConfig. WeatherSystem exposes `start(mode)`, `set_weather(name)`, `advance(delta)` and `trail`. It emits `weather_changed` with `weather`/`previous`; incoming events also switch state without recursion. RAIN_THEN_CLEAR switches after 900 simulation seconds.

Set `LightSource.rain_fragile` on exposed lamps. Ground collider `floor_material` metadata controls footprints: snow, soil and gravel accept them. Excluded materials and airborne/teleport samples break the distance segment. WeatherPresentation attaches in SceneDirector for non-clear missions, creates bounded precipitation, SE-bus rain audio and footprint AnomalyMarkers. Enemy-friendly marks remain visual only.

Validation and limitations: [weather QA](../../qa-logs/weather55/README.md). Behavior uses TDD; prose and provenance changes were reviewed for consistency without executable TDD.
