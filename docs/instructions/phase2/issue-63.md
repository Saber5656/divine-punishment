# Issue #63: M4 temple art and rainy lighting integration

Created for the upcoming runtime art integration on 2026-09-13. Starting main is `3d82853f5dd2d8ad4c2471aab80ef9ea2091a342` (PR #185). Pending PR #186 adds the eight authored lights, SearchPoints and normal-time exported route drivers; integrate that merged baseline before runtime art verification.

Retrospective baseline: #178/#179/#180 already provide physical geometry, ten active enemies, retainer escape, clock/bell, assassination and retry. The original eighteen-module Blender kit and its red/green Python interchange test were prepared before this instruction file; this document does not claim they followed it. The original checkout's unrelated dirty work and generated imports in other worktrees stay untouched.

## Purpose and chosen design

Replace the stone steps, gate, hall, bell tower, lodging, graves, cell and mill with a coherent wet mountain-temple kit. Blue-black tile and rain-dark granite separate walking levels; aged plaster and dark cedar frame the hall; warm paper lamps reveal sheltered spaces against the cold exterior. Repeated geometry uses bounded spatial batches. The Blender preview confirms a consistent stylized low-poly kit. Retain the approved game's existing look and animation sources. Avoid decorative roof slopes that hide the already validated flat roof route or close its real assassination opening.

Alternatives considered: generic castle modules do not identify the mountain temple; a new collision model would invalidate the verified paths. Use original visual modules fitted to existing physical extents. Art may add small brackets/trim outside walking height, but must not imply useful cover where no collision exists.

## Scope and compatibility

- `tools/art/build_temple_modules.py`, `assets/environment/temple_modules.{glb,json}`, `tests/art/test_temple_assets.py`: original reproducible geometry/materials, identity transforms, provenance and vertex budget.
- `src/levels/rainy_temple/temple_art.gd`, `temple_mission.tscn`: visual composition after the original scene and actor rigs initialize. Keep collision transforms/shapes/layers, navigation, traversal/observation/checkpoint markers and light gameplay properties identical.
- `tests/integration/test_temple_art.gd`: before/after physical contract, coverage of every requested area, per-light emission without self-shadowing, and retainer death/restore pose compatibility.
- `tests/smoke/temple_art_smoke.*`, `docs/qa-logs/temple63/`: native visual inspection and route/export evidence. Reuse #181 input scripts for A/B/C with active AI.
- `docs/asset-licenses.md`, module manifest and map: actual provenance and limitations.

The kit includes original retainers, umbrellas and naginata. Reuse existing animated humanoid rigs; accessories are visual children only. Do not alter shared mesh resources or combat reach. Light shades duplicate emissive materials per source and follow existing events/checkpoint state; their shell must not block the enclosed light.

## Sequence and validation

1. Commit the reviewed generator/kit/provenance as one independent unit.
2. Add and run missing-runtime contract tests; require intended failures before implementation.
3. Fit visual modules by stable authored geometry metadata, retaining roof/cell openings and all route widths. Integrate existing rainy lighting and inspect native player views of gate, roof, hall, cell and watermill.
4. Run focused Godot 4.3 GUT art/environment/checkpoint tests. Inspect assertion counts and Script/Parse errors, not exit status alone. Run the complete suite once on the final composition.
5. Export a macOS PCK and replay A/B/C sequentially with the existing release executable. Require zero failures/detections, successful C rescue, and actual B retry. Verify CI tests, three platform exports and merged-main smoke.
6. Self-review all changes; commit, publish the PR and merge after current-head CI and adopted review findings are satisfied. Close #63 only when both acceptance items are met.

Commands: `python3 -m unittest discover -s tests/art -p test_temple_assets.py`; Blender background with `--python tools/art/build_temple_modules.py -- --output assets/environment/temple_modules.glb`; `GODOT_BIN=... ./scripts/run_tests.sh`; `temple_clear_smoke.tscn -- --route=A|B|C --output-dir=OUTPUT`.

No gameplay tuning, fixed dialogue changes, campaign Post (#79), human baseline/G3 approval (#49/#84), H3 authored production (#81), release publication or unrelated work are part of this art pass. Record actual visual/route evidence and any remaining limitation in the canonical Vault task. Independent security/data-loss review is not required for this visual-only scope; main-agent self-review applies.
