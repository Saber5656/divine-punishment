# Issue #42 — production asset procurement

## Outcome and scope

Obtain a reusable residence module set, three distinct humanoid roles, and a compatible motion library. Preserve provenance, original licenses and content hashes. This asset preparation does not change gameplay or close animation integration (#43) or residence placement (#44).

## Design before production

- Use the free CC0 Standard distributions of Quaternius Universal Base Characters and Universal Animation Library. Do not use the paid Source distribution. Keep the selected source model and the 43-clip in-place library reproducible.
- Create original, stylized Japanese garments for player, ashigaru and mission target in Blender. Indigo cloth, restrained vermilion ties, dark timber and warm paper follow the approved #77 direction. No franchise reference images, characters, emblems or extracted game assets.
- Author a modular residence kit in Blender: timber posts/beams, plaster and shoji panels, floor/engawa, tiled roof, gate, fence, lantern and stone step. Dimensions are metric and origins align with a placement grid. Geometry is visual-only; #44 preserves and validates production collision separately.
- Store runtime GLB files and the source generation script. Record Blender version and generator parameters; avoid workstation paths. Keep upstream notices intact. Use existing Git LFS GLB coverage.

## Validation and completion

Asset authoring itself does not change executable game behavior, so validate its geometry, materials, rig/animation compatibility, actual Godot 4.3 import and rendered appearance rather than inventing gameplay TDD. Any reusable validation/generation behavior added will receive a failing contract check first. Review the resulting source, binaries' inventory, provenance and rendered contact sheets before commit. Required CI must pass before merge. #42 closes only when all three asset categories and the rights ledger are present; actual FSM/AnimationTree wiring belongs to #43.
