# G1 — Issue #19 Perception Formula Boundaries

Date: 2026-08-25
Gate: G1 — コード品質ゲート
Issue: #19 Unit Tests for Perception Formulas
Status: CI and independent technical QA passed; security evidence correction is in progress; merge awaits Issue #15 architecture gate

## Scope

The shared `PerceptionFormulas` module keeps the existing `PlayerVisibility` pure
API intact while making the following contracts deterministic and bounded:

- linear light attenuation, occlusion, visibility modifiers, and final clamp;
- sound distance attenuation and one-half effective-radius reduction per sound blocker;
- central/peripheral vision gain and detection-meter gain/decay accumulation.

## Checks

| Check | Result | Evidence |
|---|---|---|
| Focused GUT coverage | Pass | Code head `47cc77dc1a534cc0f5ec94c8706a0daa755f7fe1`, CI run `32748868605`, focused `5/5` |
| Full GUT suite | Pass | Code head `47cc77dc1a534cc0f5ec94c8706a0daa755f7fe1`, CI run `32748868605`, `195/195`, `1,412` assertions |
| Final docs-evidence head | Pass | `4b14e9a21ffd2cbb09cdc695df2e3c066b5947e4`, tree `49383be2ad4db26fee4913e722f71f9376e6938a`; doc-only change; CI run `32749561095` (GUT job success) |
| Independent technical QA | Pass | `qa_pass` on code head/tree `47cc77dc…` / `14235ea5…`; 5 changed paths, 275 insertions / 7 deletions |
| Independent security review | Recheck required | Initial review found no code security findings, but final docs evidence must be rechecked against the corrected head before merge |
| CI test entrypoint | Configured | `.github/workflows/ci.yml` → `scripts/run_tests.sh` |
| Local Godot/GUT execution | Not available | `godot` is not installed in this environment; CI is the execution gate |
| Diff whitespace check | Pass | local `git diff --check` |

## Merge dependency

Issue #19 is ready from its own implementation and review gates, but its sound
contract follows Issue #15's NoiseEventSystem design. PR #102 / Issue #15 remains
human-gated on ARCH-001, so PR #106 must stay unmerged until that architecture
choice is explicitly approved and the dependent integration is rechecked.

## Review handoff

The code-head test and QA evidence, corrected final docs head/tree/CI evidence, and
the remaining security and architecture gates are recorded here for the task owner.
