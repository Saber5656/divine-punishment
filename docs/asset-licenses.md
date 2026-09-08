# Divine Punishment - Asset License Ledger

作成日: 2026-07-14
ステータス: Draft v1

`CONTRIBUTING.md` §8 と `docs/08-content-specs.md` §8 に基づき、追加アセットの出典、利用根拠、改変有無を記録する。

## Cutscene Sample Keyframes - Issue #77

| Path | Category | Source | License / Usage Basis | Modifications | Notes |
|---|---|---|---|---|---|
| `assets/samples/issue-77-pv/issue77-01-exterior.png` | Cutscene style sample | Codex Image generated on 2026-07-13 from project prompt and the Issue #77 Codex baseline image | AI-generated project sample. No third-party asset source was intentionally imported. Use is governed by the generating service terms and project owner approval; perform final release clearance before shipping. | Generated keyframe; copied into repository unchanged except file rename and permission normalization. | Exterior opening reference for the approved ukiyo-e/storybook direction. |
| `assets/samples/issue-77-pv/issue77-02-corridor.png` | Cutscene style sample | Codex Image generated on 2026-07-13 from project prompt and the Issue #77 Codex baseline image | AI-generated project sample. No third-party asset source was intentionally imported. Use is governed by the generating service terms and project owner approval; perform final release clearance before shipping. | Generated keyframe; copied into repository unchanged except file rename and permission normalization. | Corridor approach reference for composition, palette, and lighting. |
| `assets/samples/issue-77-pv/issue77-03-original-codex.png` | Cutscene style sample | Codex Image generated on 2026-07-13 for Issue #77 via Codex CLI / Codex Image | AI-generated project sample. No third-party asset source was intentionally imported. Use is governed by the generating service terms and project owner approval; perform final release clearance before shipping. | Original generated baseline; copied into repository unchanged except file rename and permission normalization. | Primary style baseline praised by the product owner before additional keyframes were generated. |
| `assets/samples/issue-77-pv/issue77-04-confrontation.png` | Cutscene style sample | Codex Image generated on 2026-07-13 from project prompt and the Issue #77 Codex baseline image | AI-generated project sample. No third-party asset source was intentionally imported. Use is governed by the generating service terms and project owner approval; perform final release clearance before shipping. | Generated keyframe; copied into repository unchanged except file rename and permission normalization. | Confrontation/title-safe reference for later cutscene composition. |

## Production Notes

- Current production method for the approved sample set: Codex Image generation, using the Issue #77 baseline image as a visual reference for additional keyframes.
- Style unification method for future production: use this sample set as the reference baseline, then keep prompts, palette constraints, composition rules, and generated outputs aligned with `docs/09-ui-spec.md` §7.
- Codex Image generation in this workflow did not expose a reusable seed value. If later tooling provides seed or model-configuration controls, record them here before production-scale generation.
- This ledger records the sample/reference assets. Final commercial/release assets still require release clearance before shipping.

## UI font — Issue #42 subset

| Path | Source | License | Modification |
|---|---|---|---|
| `assets/fonts/NotoSerifJP.ttf` | [Google Fonts immutable source](https://raw.githubusercontent.com/google/fonts/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/notoserifjp/NotoSerifJP%5Bwght%5D.ttf) | SIL Open Font License 1.1; original copyright and full license in [OFL.txt](../assets/fonts/OFL.txt) | None; local filename only |

The font is bundled for Japanese UI consistency across operating systems. Do not sell the font by itself or remove its license. Each CI platform package includes a readable `NotoSerifJP-OFL.txt`; the license is also included in the exported resource bundle. Other art procurement and final release remain separate.

Source verification: font SHA256 `2fd527ba12b6a44ec30d796d633360da0aeba6c5d4af1304ce12bb4dc15a7dfc`, license SHA256 `5e0da210fb04058a8c0087985d2d456b931c2579811a49655721d3cf0c36b6d6`.

## Production procurement — Issue #42

Selected upstream sources before import:

| Source | Distribution | Rights | Planned use |
|---|---|---|---|
| [Universal Base Characters](https://quaternius.com/packs/universalbasecharacters.html), [author's download page](https://quaternius.itch.io/universal-base-characters) | Free Standard | CC0 1.0; bundled original license retained | Original clothed player, ashigaru and target variants |
| [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html), [author's download page](https://quaternius.itch.io/universal-animation-library) | Free Standard, 43 in-place clips | CC0 1.0; bundled original license retained | Common humanoid animation source for #43 |

The Blender-authored residence kit and clothing are original project geometry, using no official franchise IP or extracted game assets. This is procurement and provenance documentation; it does not claim that all gameplay animation contexts are already integrated.

Delivered files:

- `assets/characters/{shinobi,ashigaru,magistrate}.glb`: derived from the Standard `Superhero_Male_FullBody.gltf` mesh and rig. Original role garments, headwear and accessories were authored by this project; occluded body surfaces removed and garment skin weights transferred. Full upstream notice: `assets/characters/QUATERNIUS-LICENSE.txt`.
- `assets/animations/quaternius_standard.glb`: unmodified in-place `Unreal-Godot/UAL1_Standard.glb`; 43 clips, no paid Source-only content. Full notice: `assets/animations/QUATERNIUS-LICENSE.txt`.
- `assets/environment/residence_modules.glb`: twelve original Blender-authored residence modules. No external architecture assets or textures. Geometry can be regenerated from `tools/art/build_production_assets.py`.
- `assets/production-assets.json`: upstream archive SHA256, author source links, Blender version, units and module inventory. Source download grants and local machine paths are deliberately excluded.

The upstream base distribution references two normal images with an extra `_png` suffix. The importer resolves those two filenames to their existing sibling files in a temporary glTF, preserving the original downloaded archive. No unrelated replacements are downloaded. The supplied Standard body uses the author's humanoid skeleton; #43 remains responsible for retargeting the animation source and validating game stances and assassination contexts.

Rights review: both obtained distributions explicitly dedicate their content under CC0 1.0. Acquisition was from the author's own free downloads, without importing franchise assets, logos, extracted game files or franchise reference art. Original additions use project-authored shapes. This records the actual sources and review performed; it is not a claim about undisclosed upstream provenance.

## Original synthesized game audio (#46)

| Files | Source | Third-party license |
|---|---|---|
| `assets/audio/*.wav` | `tools/audio/build_audio.py`, deterministic original synthesis | None; no external recordings, samples or melodies used |
| `assets/audio/sources.json` | Per-cue duration, peak level, loop flag and generator provenance | Project metadata |

The library contains synthesized wind/insects, flute-like and drum-like layers,
seven floor materials, five ninja tool cues, doors, water, landings, combat,
assassination, detection, results and bell cues. It is not a set of recorded
traditional instruments or human voices. The original generator and provenance
are retained with the assets. `ORIGINAL-AUDIO-NOTICE.txt` travels with exports.
