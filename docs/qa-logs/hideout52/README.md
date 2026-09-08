# Hideout system validation

Main-agent implementation and self-review, Godot 4.3, 2026-09-08.

Two regression tests first failed because h1–h8 and the result continuation API were missing. After implementation, both passed (45 assertions). Additional checks cover the seen-variant receipt and repeat-clear navigation. Branch checks exercise each threshold and threshold+1, and shared scenes at high shura.

Self-review checked first-clear capture before persistence, selection cleanup and pause restoration, localized resource validity, immutable resource playback copies, and canonical dialogue against docs/06-narrative.md. A generation script initially used the wrong typed-constant anchor; only the failed SceneDirector patch was retried, preserving already-created CSV entries without duplicates.

The background is an original provisional gradient, not the final #78 illustration. H5's dry setting is stated in text; final visual verification of that setting remains with #78/#81. Automated playback is not a human playtest.

Verified full suite: exit0,538 passing tests/4429 assertions, Python3 tests passed and catalog0 findings. Native exported release playback exercised all8 scenes at shura0 and100 (16 runs), with no failures or engine/script errors. Self-review then found missing reduced-mode selection: a new assertion failed, the host now passes reduced_mode=true, and the affected2 tests/50 assertions pass. The final re-exported release also completed all16 playback runs without failure. Export logs retain known development GUT-loader and shutdown warnings; the exported native playback itself is clean.
