# Issue #45: residence lighting

Godot 4.3 Forward+ / Apple M4, 2026-09-08. Self-reviewed before commit.

Static residence geometry is exported to 76 UV2 meshes and baked with LightmapGI. The final preset uses LOW quality with denoising, texel scale 0.5, two bounces and probe subdivision 4; the successful GPU bake took 411 seconds. Moon shadows are baked. Only extinguishable gameplay lights use dynamic shadows. Moving actors receive probe lighting. Night grading uses saturation 0.65 and contrast 1.12.

The `.exr.import` is intentional: the bake is a two-slice texture array, not an ordinary Texture2D. Meshes and EXR use Git LFS. The manifest is included in all export presets.

## Verification

- TDD: missing integration failed, then the lighting regression passed 59 assertions.
- Integrated suite after audio #155: 519 tests / 4278 assertions passed.
- Native editor and exported PCK running in the actual macOS release executable both passed all four diagnostic cases. These are fixed camera comparisons, not human playtesting.

| Case | Gameplay/debug V | Exported center luminance |
|---|---:|---:|
| Lantern on | 0.561396 | 0.139033 |
| Same position, off | 0.040000 | 0.053634 |
| Far away | 0.040000 | 0.062275 |
| Under floor | 0.012000 | 0.007185 |

The screenshot luminance is measured before the debug overlay. The overlay reports the same visibility value as gameplay. Near-on and under-floor captures were visually inspected. Darkness readability and performance acceptance remain separate playtest/performance work.

Export produced a working 266824112-byte PCK. The export process also reported a stale GUT editor-scene reference and shutdown resource warnings; the release smoke itself completed with zero failures and an ObjectDB shutdown warning. This is not a claim of warning-free engine shutdown.

## Reproduction and review

Run `tools/lighting/prepare_lightmap_scene.gd` with `--output-project` pointing to a fresh external directory, then `python3 tools/lighting/bake_residence.py --godot GODOT_EDITOR --project OUTPUT_PROJECT`. The helper refuses to overwrite existing project settings. Baking requires the native editor/GPU; it is not a headless runtime operation. Copy verified bake assets back, preserving the EXR importer metadata. Run `tests/smoke/residence_lighting_smoke.tscn` with `--output-dir` for comparisons.

Self-review checked source-art fallback, collision/navigation preservation, static versus dynamic light ownership, export manifest inclusion and texture-array import. Existing source-art contract tests deliberately use `use_baked=false`; the lighting test exercises the production baked scene.

Earlier attempts were retained in the private task evidence: a temporary editor fixture established real bake output; joined-mesh UV unwrapping was replaced with cached source UVs; the medium-quality bake was stopped without a completed result before the documented LOW preset succeeded. No temporary editor plugin/settings are shipped in the game project.

Reference: [Godot 4.3 LightmapGI](https://docs.godotengine.org/en/4.3/tutorials/3d/global_illumination/using_lightmap_gi.html).
