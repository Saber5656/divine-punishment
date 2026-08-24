# G1 — Issue #19 Perception Formula Boundaries

Date: 2026-08-25
Gate: G1 — コード品質ゲート
Issue: #19 Unit Tests for Perception Formulas
Status: Awaiting CI run on the pushed branch

## Scope

The shared `PerceptionFormulas` module keeps the existing `PlayerVisibility` pure
API intact while making the following contracts deterministic and bounded:

- linear light attenuation, occlusion, visibility modifiers, and final clamp;
- sound distance attenuation and one-half effective-radius reduction per sound blocker;
- central/peripheral vision gain and detection-meter gain/decay accumulation.

## Checks

| Check | Result | Evidence |
|---|---|---|
| Focused GUT coverage added | Pass (pending execution) | `tests/unit/test_perception_formulas.gd` |
| CI test entrypoint | Configured | `.github/workflows/ci.yml` → `scripts/run_tests.sh` |
| Local Godot/GUT execution | Not available | `godot` is not installed in this environment; CI is the execution gate |
| Diff whitespace check | Pass | `git diff --cached --check` before commit |

## Review handoff

The final CI result, independent review verdicts, pushed commit SHA, and any
review-thread fixes must be appended by the task owner before the issue is
marked complete.
