# Issue #1: Godot 4 プロジェクト初期化とディレクトリ構成

- Milestone: M0 / ラベル: area:infra, type:feature
- 依存: なし（最初の Issue）
- ゲート: G1

## 目的

Godot 4.3 stable のプロジェクトを作成し、以降の全 Issue が同じディレクトリ構成・レンダラ・物理レイヤー・LFS 設定の上で作業できる土台を固定する。ここで決めた設定はすべて後続の契約になるため、docs との一字一句の一致を最優先する。

## 読むべき仕様（読む順）

1. docs/03-technical-design.md 冒頭注記 + §1–§2 — バージョン固定・レンダラ・ディレクトリ
2. docs/08-content-specs.md §10.3 — 物理レイヤー名（登録する文字列そのもの）
3. CONTRIBUTING.md — 本 Issue で参照リンクを README に張るため全体を一読

## 変更対象パス

| パス | 種別 | 内容 |
|---|---|---|
| `project.godot` | 新規 | プロジェクト設定（下記手順 2–4） |
| `src/` `data/` `tests/` の各サブディレクトリ | 新規 | docs/03 §2 の構成どおり。空ディレクトリは `.gitkeep` |
| `.gitignore` | 新規 | Godot 4 標準（`.godot/`, `*.import` は追跡: Godot4 では `.godot/` のみ無視で可） |
| `.gitattributes` | 新規 | LFS: `*.png` `*.jpg` `*.glb` `*.ogg` `*.wav` `*.ttf` `*.otf` |
| `icon.svg` | 新規 | Godot デフォルトで可（アートは #42 以降） |

## 実装手順

1. Godot **4.3 系 stable の最新パッチ**（例: 4.3.x）でプロジェクト新規作成。使用した正確なバージョンを `README.md` の環境欄と本指示書末尾に追記する
2. `project.godot` 設定:
   - `application/config/name = "Divine Punishment"`
   - レンダラ: `rendering/renderer/rendering_method = "forward_plus"`
   - メインシーン: 仮に `src/ui/main.tscn`（空の Node を置く。画面フロー実装は #36）
3. 物理レイヤー名を **docs/08 §10.3 の表の名称どおり** `layer_names/3d_physics/layer_1..15` に登録する（例: layer_1 = `world`, layer_5 = `vision_blocker` … layer_15 = `mission_trigger`。16–20 は未登録のまま）
4. `physics/3d/physics_engine` は既定（GodotPhysics）のまま変更しない
5. docs/03 §2 のツリーどおりにディレクトリを作成（`addons/` は #2 で作るため不要）
6. `.gitignore` / `.gitattributes` を作成し、`git lfs install` 済みであることを確認
7. `git lfs track` の結果が .gitattributes と一致することを確認

## 検証手順

```bash
# 1. エディタなしで起動して即終了できる（設定破損がない）
godot --headless --quit --path .   # 終了コード 0、エラーログなし

# 2. レイヤー名が契約どおり登録されている
grep -A20 '3d_physics' project.godot   # world / vision_blocker 等 15 件が §10.3 と一致

# 3. LFS 対象の確認
git lfs track   # png/jpg/glb/ogg/wav/ttf/otf が列挙される
```

- 手動確認: エディタでプロジェクトを開き、Project Settings → Layer Names → 3D Physics が表に一致するスクリーンショットを PR に添付

## 完了条件（DoD）

- [ ] Issue #1 受け入れ条件 全チェック（CONTRIBUTING.md の作成は本リポジトリに既にあるため「リンク確認」に読み替え）
- [ ] 使用した Godot の正確なバージョン（4.3.x）を README に記録した
- [ ] レイヤー名 15 件が docs/08 §10.3 と一字一句一致
- [ ] CONTRIBUTING §4 共通 DoD

## レビュー観点

- レイヤー番号のズレ（1 個ずれると以降全 Issue のマスク値が壊れる）— §10.3 と突き合わせて全件確認すること
- `rendering_method` が `mobile` / `gl_compatibility` になっていないか
- ディレクトリ名の綴り（`interactables` 等）が docs/03 §2 と一致するか

## 実装しないこと（スコープ外）

- InputMap の登録（#6）、autoload 登録（#5）、GUT（#2）、CI（#3）、エクスポートプリセット（#3）
