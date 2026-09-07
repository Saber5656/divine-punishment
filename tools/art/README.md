# Production art tools

Use Blender 5.2 LTS. Download the **free Standard** archives linked in `assets/production-assets.json`, verify their recorded SHA256 values, and extract them outside the repository. Do not purchase the Source editions for this workflow.

```sh
"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 \
  --python tools/art/build_production_assets.py -- \
  --base-kit "$BASE_KIT_DIR" --animation-kit "$ANIMATION_KIT_DIR" --output assets
python3 -m unittest discover -s tests/art -v
"$GODOT_BIN" --headless --path . --import
"$BLENDER_BIN" --background --python-exit-code 1 \
  --python tools/art/render_contact_sheet.py -- --assets assets \
  --kind characters --output "$ART_REVIEW_DIR/characters.png"
```

Use `--kind architecture` for the module contact sheet. GLB binaries use Git LFS. The generator imports external files only from the explicitly supplied archive directories, repairs two known upstream texture references in a temporary sibling file, and writes generated files under `--output`.

Characters have foot origins, face local +Z after glTF import, and share named humanoid bones. Rotate the visual model by PI about Y to match gameplay forward -Z. Player/AI capsules are centred vertically, so game integration needs a model offset; do not move the gameplay capsule to match a mesh. The Standard motion library is kept unchanged as retargeting input. The character models intentionally have no active animation player yet. AnimationTree/FSM integration and pose-specific clipping checks are #43.

Residence modules use metres and origin-aligned local coordinates. `floor_2m`, `shoji_2m`, `plaster_2m`, `engawa_2m`, `roof_2m`, `ridge_2m`, `beam_2m`, `fence_2m` are 2-metre grid pieces; posts are 2.8 metres high and the gate spans 4 metres. The library places modules at their own origins; instantiate the selected named mesh rather than the overlapping whole library. They contain visual meshes only. Navigation, climbing and collision placement are validated separately in #44.

No executable gameplay behavior is changed by this procurement. Validation includes a deliberately failing missing-asset contract before generation, GLB container/rig/module/license checks after generation, actual Godot import and rendered visual review. The first exploratory clothing surface was rejected for clipping and replaced with a separate weighted garment mesh; only the reviewed final models are delivered.
