# Smoke duration CI recovery

Baseline: main `f5c88d7bf4e1e1fb8a65c5188149246dc0e0a17c`. Existing smoke code and prior passing CI are retrospective evidence.

Purpose: restore integrated CI after run 34079581630 exposed floating-point cancellation in the hard five-second smoke timer. `(3.018 + 5.0) - 3.018` can exceed `5.0`.

Scope: `src/tools/effects/smoke_bomb_effect.gd`, `tests/unit/test_ninja_tools.gd`, this instruction. Preserve radius, duration tuning, visibility geometry, scene contracts and API return values. Use monotonic integer milliseconds for expiry and convert the final nonnegative difference to seconds.

Acceptance: remaining duration never exceeds configured duration; exact expiry disables smoke; fractional-millisecond configured durations must not extend their duration; original finite-segment visibility and five-meter/five-second limits remain.

Validation: deterministic clock regression at 3018 ms, near/exact expiry and shorter configured duration; focused ninja tools tests; one full Godot 4.3 GUT run; PR GUT and merged-main GUT/three-platform Export. Record outcomes/source SHA in canonical TSK-1351 task. Normal-risk correction, review not required under current user instructions. No gameplay balance or persistence changes.
