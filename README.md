# divine-punishment

[![CI](https://github.com/Saber5656/divine-punishment/actions/workflows/ci.yml/badge.svg)](https://github.com/Saber5656/divine-punishment/actions/workflows/ci.yml)

『天誅4 (Tenchu: Shadow Assassins)』に inspired された精神的続編 — 戦国の闇を舞台にした cinematic stealth-puzzle ninja game。

公式 IP・キャラクター名・設定は使用しない。

- エンジン: Godot 4 / PC (Steam 想定)
- 視点: 三人称 3D、箱庭ミッション構造
- スコープ: フルゲーム（全 10 ミッション + ストーリーエンドまで）。Phase 1 = Vertical Slice / Phase 2 = キャンペーン

## Environment

- Godot: `4.3-stable` 固定
- GUT: `v9.4.0`
- Git LFS: `*.png`, `*.jpg`, `*.glb`, `*.ogg`, `*.wav`, `*.ttf`, `*.otf`

ローカルで `godot` が PATH にない場合は、検証時に `GODOT_BIN=/path/to/Godot` を指定する。

## ドキュメント（実装エージェントは 00-vision の「読み順」に従うこと）

| ドキュメント | 内容 |
|---|---|
| [tenchu4-concept-research.md](tenchu4-concept-research.md) | 元作品のコンセプト調査 |
| [docs/00-vision.md](docs/00-vision.md) | ビジョン・デザインピラー・確定事項・ドキュメント読み順 |
| [docs/01-requirements.md](docs/01-requirements.md) | 要件定義（Phase 1/2・FR/NFR・受け入れ基準） |
| [docs/02-game-design.md](docs/02-game-design.md) | ゲームデザイン仕様（コアメカニクス） |
| [docs/03-technical-design.md](docs/03-technical-design.md) | 技術設計（Godot アーキテクチャ） |
| [docs/04-level-design.md](docs/04-level-design.md) | レベル設計原則と M1/M2 詳細 |
| [docs/05-milestones.md](docs/05-milestones.md) | マイルストーン M0〜M12・Issue 分割 |
| [docs/06-narrative.md](docs/06-narrative.md) | ナラティブ設計（脚本・確定台詞・修羅値） |
| [docs/07-campaign-missions.md](docs/07-campaign-missions.md) | 全 10 ミッション設計・拡張メカニクス |
| [docs/08-content-specs.md](docs/08-content-specs.md) | 実装コントラクト（スキーマ・シグナル・数値表） |
| [docs/09-ui-spec.md](docs/09-ui-spec.md) | UI / 画面 / HUD / カットシーン画風仕様 |
| [docs/10-quality-gates.md](docs/10-quality-gates.md) | 品質ゲート（G1〜G5: 判定者・合否基準・記録） |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 開発規約（コーディング / PR / DoD / 指示書・分割ルール） |
| [docs/instructions/](docs/instructions/) | Issue 実行指示書（マイルストーン着手時に作成。M0 分作成済み） |
| [docs/maps/](docs/maps/) | ミッションのマップ図面（座標・配置の正本。見本: m02） |

## 開発の進め方

作業は GitHub Issues（Milestone M0〜M12）で管理する。分割方針は [docs/05-milestones.md](docs/05-milestones.md) を参照。

実装者は着手前に必ず: ① [CONTRIBUTING.md](CONTRIBUTING.md) を読む → ② 担当 Issue の指示書（`docs/instructions/`）に従う → ③ 完了時に [品質ゲート](docs/10-quality-gates.md) の判定を受ける。
