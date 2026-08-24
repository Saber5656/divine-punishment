# G1 — Issue #19 Perception Formula Boundaries

Date: 2026-08-25
Gate: G1 — コード品質ゲート
Issue: #19 Unit Tests for Perception Formulas
Status: CI and independent QA passed; merge awaits Issue #15 architecture gate

## Scope

The shared `PerceptionFormulas` module keeps the existing `PlayerVisibility` pure
API intact while making the following contracts deterministic and bounded:

- linear light attenuation, occlusion, visibility modifiers, and final clamp;
- sound distance attenuation and one-half effective-radius reduction per sound blocker;
- central/peripheral vision gain and detection-meter gain/decay accumulation.

## Checks

| Check | Result | Evidence |
|---|---|---|
| Focused GUT coverage | Pass | CI run `32748868605`, focused `5/5` |
| Full GUT suite | Pass | CI run `32748868605`, `195/195`, `1,412` assertions |
| Exact reviewed head | Pass | `47cc77dc1a534cc0f5ec94c8706a0daa755f7fe1`, tree `14235ea5a265dfbd25cdce9f89e743ac378a98c2` |
| Independent technical QA | Pass | `qa_pass`; 5 changed paths, 275 insertions / 7 deletions |
| CI test entrypoint | Configured | `.github/workflows/ci.yml` → `scripts/run_tests.sh` |
| Local Godot/GUT execution | Not available | `godot` is not installed in this environment; CI is the execution gate |
| Diff whitespace check | Pass | local `git diff --check` |

## Merge dependency

Issue #19 is ready from its own implementation and review gates, but its sound
contract follows Issue #15's NoiseEventSystem design. PR #102 / Issue #15 remains
human-gated on ARCH-001, so PR #106 must stay unmerged until that architecture
choice is explicitly approved and the dependent integration is rechecked.

## Review handoff

The final CI result, independent QA verdict, exact remote head/tree, and the
remaining architecture dependency are recorded here for the task owner.
