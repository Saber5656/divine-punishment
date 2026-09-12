# M4 temple art and rainy lighting (#63)

The playable temple now uses an original Blender 5.2.1 LTS kit for stone paving/steps/retaining walls, cedar and plaster, gate/hall/bell-tower/lodging framing, roof tiles/eaves, graves, suspended bronze bell, sheltered lanterns, outdoor braziers, mill wheel and cliff skins. The eighteen-module source kit includes one spare cell-lattice module; seventeen module types are used in the scene. Original clothed retainers replace capsules. Existing animated humanoid rigs receive instance-specific monk cloth, umbrellas following the left hand and a target naginata following the existing right-hand weapon attachment. Combat reach and AI remain unchanged.

The generator, baked identity transforms, interchange test and provenance are committed under `tools/art`, `tests/art` and `assets/environment`. No external models, images or material downloads were added. [Asset provenance](../../asset-licenses.md#original-mountain-temple-modules-63) retains the existing Quaternius character attribution. The original module review image is a Blender Cycles preview; the following game images are actual exported Godot 4.3 rendering, not mockups.

## Physical and visual contracts

Art fits the existing collision extents. Top relief stays inside the supported roof/floor surface; each existing hole is handled as separate physical pieces. The flat walkable roof and its real beam opening remain visible. Wall frames are present on both sides; cliff skins stay inside the original boundary. Spatial 16 m batches preserve culling. Lamp shades do not shadow their own lights, and per-source emissive materials follow extinction/relight without mutating other lamps. Bell and lantern hangers remove floating fixtures. Retainer death and checkpoint restoration retain the original body transforms.

Cold ambient/moon light and wet stone/tile contrast with the eight authored warm lights. Their radius, gameplay intensity, extinguishability and positions are unchanged. The actual gameplay contract is captured before and after art: collision transforms/shapes/layers, navigation vertices/polygons, traversal/observation markers and light parameters compare equal.

Native inspection found rain passing through solid roofs. A temple-specific particle draw shader now clips precipitation below the nine actual roof pieces while retaining the real beam opening. The existing 600 outdoor particles, rain process material/audio and gameplay footstep/vision rules remain intact; there is still exactly one existing WeatherPresentation owner. Shader coordinates and uniforms use the [Godot 4.3 spatial reference](https://docs.godotengine.org/en/4.3/tutorials/shaders/shader_reference/spatial_shader.html) and [shader language reference](https://docs.godotengine.org/en/4.3/tutorials/shaders/shader_reference/shading_language.html).

## Verification

- Original kit TDD: missing asset first fails, then passes the interchange contract. All seven Python art contract tests pass; text catalog lint has zero findings.
- Runtime art TDD: three missing-art failures become **3 tests / 34 assertions**. Native review then fixes one-sided frames, bell darkness, missing hangers and boundary presentation.
- Complete integrated local GUT regression on the art composition: **678 tests / 5,516 assertions**, 164.315 seconds, no Script/Parse errors. Known dummy-renderer/shutdown warnings remain.
- The subsequent rain-only correction adds an intended failing test, then passes **4 art tests / 43 assertions**. Tests check covered hall/cell, open courtyard, above-roof rain and the actual beam hole, plus unchanged particle count. The prior complete suite is reused because this correction only changes rain rendering; current-head CI runs the final combined suite.
- `tests/smoke/temple_art_smoke.tscn -- --output-dir=OUTPUT` captures the actual campaign scene from eight cameras, tests lamp on/off, then uses two explicit player placements to inspect sheltered/outdoor precipitation. Active AI and the normal clock remain enabled. This fixture is visual inspection, not route proof. Its final exported run exited 0, recorded equal physical contracts, and produced the inspected screenshots below. No Script/Parse or engine ERROR was observed in final native rendering.

| Exported normal-time route | Time | Score | Detections / civilian / non-target kills |
|---|---:|---:|---|
| A front steps / hall | 134.014 s | 75 | 0 / 0 / 0 |
| B cliff / roof / beam | 127.790 s | 75 | 0 / 0 / 0 |
| C stream / crawl / rescue | 208.570 s | 80 | 0 / 0 / 0 |

All runs use the unchanged [temple181 mapped-input driver](../temple181/README.md), with real movement/collision, active AI and a volatile save. All exit 0 with no failures, unlock M5 and retain Shura 0. C physically evacuates both retainers. B's real scene retry restores the defeated target and saved roof posture in **219.619 ms**. Target corpses may be found, so these scores do not claim the no-traces bonus.

B/C ran on the complete art composition `95b01f3`; A was rerun on the final rain correction `339a963` after final exported visual inspection. Only precipitation drawing differs between these builds; geometry, controls, AI, light gameplay, rescue and checkpoint logic are identical. This is deliberate reuse of unaffected route evidence, not a claim that all three came from one binary. Result JSON preserves the exact observations.

The kit remains stylized low-poly. Retainers use the existing translation/death-pose presentation, not newly authored skeletal walking clips. Overall performance acceptance (#48), human baseline/G3 evaluation (#49/#84), campaign Post (#79) and remaining hideout production (#81) are separate. No release was published.

![Original Blender module preview](kit.png)

![Gate, courtyard and monks in the actual game](gate.png)

![Suspended bell and sheltered lantern](bell.png)

![Clothed retainers and the real crawl exit](cell.png)

![Rain is clipped under the solid hall roof](rain-covered.png)

![Rain remains outdoors](rain-outdoor.png)
