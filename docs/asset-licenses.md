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
