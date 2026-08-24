# G1 — Issue #19 Perception Formula Boundaries

Date: 2026-08-25
Gate: G1 — コード品質ゲート
Issue: #19 Unit Tests for Perception Formulas
Status: CI, independent technical QA, and security review passed; merge awaits Issue #15 architecture gate

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
| Docs-evidence validation parent | Pass | `2841fc9c1c35ec2597d2757b70ca48001ee2b8fb`, tree `49383be2ad4db26fee4913e722f71f9376e6938a`; docs-only, CI run `32750802660` (GUT job success). This append-only correction is the child of that validated evidence commit; its newly assigned Git object ID is intentionally not self-referenced. |
| Independent technical QA | Pass | `qa_pass` on code head/tree `47cc77dc…` / `14235ea5…`; 5 changed paths, 275 insertions / 7 deletions |
| Independent security review | Pass | `security_clear` on code and docs-evidence parent `2841fc9…`; no code security findings, no new auth/input/DoS/secret/CI risks; this correction changes documentation only |
| CI test entrypoint | Configured | `.github/workflows/ci.yml` → `scripts/run_tests.sh` |
| Local Godot/GUT execution | Not available | `godot` is not installed in this environment; CI is the execution gate |
| Diff whitespace check | Pass | local `git diff --check` |

## Merge dependency

Issue #19 is ready from its own implementation and review gates, but its sound
contract follows Issue #15's NoiseEventSystem design. PR #102 / Issue #15 remains
human-gated on ARCH-001, so PR #106 must stay unmerged until that architecture
choice is explicitly approved and the dependent integration is rechecked.

## Review handoff

The code-head test and QA evidence, the validated docs-evidence parent, the
security verdict, and the remaining architecture gate are recorded here. The
self-referential current child SHA is intentionally omitted; PR metadata and CI
provide its exact immutable identity.
