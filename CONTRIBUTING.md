# CONTRIBUTING — 開発規約

作成日: 2026-07-04
対象: 本リポジトリで実装を行うすべての人間・AI エージェント

本書は「誰が実行しても同じ品質の成果物」を出すための運用規約である。仕様の正本は docs/（読み順は [docs/00-vision.md](docs/00-vision.md) 末尾）、実装コントラクトの正本は [docs/08-content-specs.md](docs/08-content-specs.md)。

## 1. 環境

- **Godot 4.3 stable 固定**（docs/03 冒頭）。バージョン変更は専用 Issue でのみ行う
- GDScript のみ。C# / GDExtension の導入は事前に Issue で合意する

## 2. コーディング規約

| 項目 | 規約 |
|---|---|
| ファイル / ディレクトリ名 | snake_case（`enemy_brain.gd`）。配置は docs/03 §2 に従う |
| クラス | 再利用されるクラスは `class_name` を PascalCase で宣言 |
| 型付け | 変数・引数・返り値すべて型注釈必須（`-> void` 含む）。`Variant` の使用は理由コメント必須 |
| シグナル名 | 過去形または名詞（`state_changed`, `noise_emitted`）。定義は EventBus（グローバル）か自クラス（ローカル）のみ |
| 定数・enum | 共通 enum は `src/core/enums.gd` に集約（docs/08 §10.0）。マジックナンバー禁止 — 数値は `data/tuning/` の Resource から引く（NFR-04） |
| ノード間参照 | シーンをまたぐ直接参照禁止。EventBus シグナル + グループ（`lights` / `enemies` / `civilians` / `player_detect_points`）を使う（docs/03 §3.1） |
| ノードパス | docs/08 §10.2 のツリー構造を変更しない。変更が必要なら先に 08 を修正する PR を出す |
| コメント | コードで表せない制約・理由のみ書く。「何をしているか」の逐語コメント禁止 |
| pure 関数 | ユニットテスト対象の数式・判定は `static func`（副作用なし）に分離する（docs/08 §10.1 の pure 指定に従う） |

## 3. Git / PR 運用

- ブランチ名: `feat/issue-<番号>-<slug>` / `fix/issue-<番号>-<slug>` / `docs/<slug>`
- **1 Issue = 1 PR**。PR タイトル・本文は英語、本文に `Closes #<番号>` を含める
- main への直接 push 禁止。PR は CI green + レビュー 1 件通過でマージ
- コミットは意味単位で分割。仕様変更（docs/08 のコントラクト変更）は**同一 PR 内で** docs を先に更新するコミットを含める

## 4. Definition of Done（全 Issue 共通・PR 本文にチェックリストとして貼る）

- [ ] Issue の受け入れ条件をすべて満たしている
- [ ] docs/08-content-specs.md §10（API / シーンツリー / レイヤー / FSM）に準拠している
- [ ] pure 指定の関数に GUT ユニットテストがある
- [ ] 数値をハードコードしていない（data/tuning/ 経由）
- [ ] 仕様と実装が食い違った場合、実装側で黙って解決せず docs を修正するコミットを含めた
- [ ] 動作確認手順（起動して何をどう確認したか）を PR 本文に記載した
- [ ] 該当する品質ゲート（docs/10-quality-gates.md）の合否記録を残した

## 5. Just-in-Time 指示書ルール

- 各 Issue の**実行指示書**は `docs/instructions/M<マイルストーン>/issue-<番号>.md` に置く（テンプレ: [docs/instructions/TEMPLATE.md](docs/instructions/TEMPLATE.md)）
- **マイルストーン着手時**に、そのマイルストーン全 Issue の指示書を作成してから実装を開始する（前倒しで全部書かない — 陳腐化を防ぐため）
- 指示書の作成者は、直前マイルストーンの実装結果（実際のファイル構成・実測工数）を反映する
- 指示書と Issue 本文が食い違う場合は指示書が優先。ただし食い違いを見つけたら Issue 側にコメントを残す
- M0 の指示書 5 本を粒度の基準サンプルとする

## 6. エピック分割ルール（ミッション制作 Issue）

ミッションのゲームプレイ実装 Issue（#60, #62, #64, #66, #68, #70, #72, #75）はエピックであり、**着手前に以下の 4 サブ Issue に分割してから実装する**（親 Issue はトラッキング用に残し、サブ Issue を紐付ける）:

1. `<ミッション名>: レイアウト & 経路` — 地形・層構造・マーカー配置・3 経路の通行確認（マップ図を docs/maps/ に作成してから着手。見本: [docs/maps/m02-yashiki.md](docs/maps/m02-yashiki.md)）
2. `<ミッション名>: 敵配置 & ルーチン` — 敵・民間人・標的の配置と巡回 / 周期ルーチン
3. `<ミッション名>: 固有ギミック` — そのミッション固有のシステム（花火・鐘・おびき出し等）
4. `<ミッション名>: 通し検証 & チューニング` — 07 付録チェックリスト全通過・基準時間実測・ゲート G3 判定

## 7. テスト

- ユニットテスト: `tests/unit/test_<対象>.gd`（GUT）。pure 関数・遷移表・集計ロジックが対象
- 実行: `./scripts/run_tests.sh`（headless）。CI と同一コマンド
- 統合スモーク: シーン読み込み・セーブ往復は `tests/integration/`
- 手動検証: デバッグオーバーレイ（Issue #18）のトグルで数値確認し、手順を PR に記録

## 8. アセット

- 追加するすべての外部アセットは `docs/asset-licenses.md` に 出典 / ライセンス / 改変有無 を記録してから import する
- 公式 IP（天誅）由来のアセット・名称は一切禁止（NFR-03）
- バイナリは Git LFS（.gitattributes 参照）
