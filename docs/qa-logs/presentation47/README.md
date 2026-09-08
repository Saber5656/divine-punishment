# Issue #47 presentation verification

Godot 4.3 native Forward+, Apple M4, 2026-09-08.

The four existing 1.25-second assassination sequences retain their distinct actor clips and camera offsets, adding a bounded 3/5-degree FOV envelope and subtle framing bars. The existing audio silence/beat/restore timeline remains authoritative. Detection now triggers the authored SE and a single 0.8-second edge pulse, with repeated events suppressed during that pulse. The screen centre stays clear. The result rank eases in over 0.9 seconds while gameplay is paused; initial focus stays on the rank so small windows do not immediately scroll past it. Navigation remains available throughout. UI stingers continue processing during pause.

## Evidence

- Missing presentation implementation: two expected red tests, then 29 assertions passed.
- Integrated suite before the focus correction: 521 tests / 4307 assertions passed.
- Native initial four-context sequence: back 1.848 s, above 1.258 s, below 1.250 s, corner 1.258 s, zero failures. Correct actor clip per context, FOV restored to 75 after each. First-use shader/frame overhead is included in wall time.
- Visual review covered assassination framing, red detection edges and result text. It found initial button focus scrolling the heading away. A third regression reproduced this, and initial rank focus corrects it.
- These are controlled presentation captures in the practice scene, not human playtests or proof of context geometry eligibility. Existing resolver tests cover eligibility, cancellation, frame stalls and 1–2-second bounds.
- Headless dummy-renderer and ObjectDB shutdown warnings remain; no script errors were observed in the integrated run.

Self-review: no input interception by the overlay, bounded effects, FOV restoration on cancellation/completion, pause-safe result animation/audio, no real campaign completion written by the smoke fixture. Source changes contain no private paths or external assets.

Reproduce with `tests/smoke/final_presentation_smoke.tscn -- --output-dir=OUTPUT_DIR`. Tests live in `tests/integration/test_final_presentation.gd`.

Final focus regression: 3 tests / 30 assertions passed. Final native sequence: back 1.311 s, above 1.258 s, below 1.253 s, corner 1.257 s, zero failures; the result heading and rank remain visible. Final native run had no logged script/engine errors.

Final integrated suite including rank-focus correction: 522 tests / 4308 assertions passed. No script errors.
