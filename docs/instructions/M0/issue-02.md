# Issue #2: GUT 導入とユニットテスト雛形

- Milestone: M0 / ラベル: area:infra, type:test
- 依存: #1
- ゲート: G1

## 目的

GUT（Godot Unit Test）を導入し、「headless で 1 コマンド実行 → 終了コードで合否判定」できる状態を作る。このコマンドがそのまま CI（#3）と全開発者のローカル検証の共通入口になる。

## 読むべき仕様（読む順）

1. docs/03-technical-design.md §9 — テスト方針
2. CONTRIBUTING.md §7 — テスト規約（ファイル命名）

## 変更対象パス

| パス | 種別 | 内容 |
|---|---|---|
| `addons/gut/` | 新規 | GUT 本体（Godot 4.3 対応の GUT 9.x 系に固定。導入した正確なバージョンを本指示書末尾と README に記録） |
| `tests/unit/test_sample.gd` | 新規 | 雛形テスト（下記） |
| `tests/integration/.gitkeep` | 新規 | |
| `scripts/run_tests.sh` | 新規 | 実行スクリプト（実行権限付与） |
| `.gutconfig.json` | 新規 | dirs: `res://tests/unit`, `res://tests/integration` / `should_exit: true` |

## 実装手順

1. GUT を AssetLib からではなく **GitHub リリースの zip を固定バージョンで取得**して `addons/gut/` に展開する（AssetLib はバージョンが動くため）。取得元 URL とバージョンを PR 本文に記載
2. Project Settings → Plugins で GUT を有効化（`project.godot` に反映される）
3. 雛形テスト `tests/unit/test_sample.gd`:

```gdscript
extends GutTest

func test_project_boots() -> void:
    assert_true(true)

func test_enums_will_live_here() -> void:
    # #5 で src/core/enums.gd が入ったらこのテストを置き換える
    pass_test("placeholder")
```

4. `scripts/run_tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
godot --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

5. 失敗テストを一時的に書いて**終了コードが非 0 になることを確認**してから消す（「常に緑のテスト基盤」事故の防止。確認した旨を PR に記載）

## 検証手順

```bash
./scripts/run_tests.sh          # 全件 pass・終了コード 0
echo $?                          # → 0
# 一時的に assert_true(false) を入れた状態で:
./scripts/run_tests.sh; echo $?  # → 非 0 を確認後、元に戻す
```

## 完了条件（DoD）

- [ ] Issue #2 受け入れ条件 全チェック
- [ ] GUT のバージョンが固定・記録されている
- [ ] 失敗時に終了コード非 0 になることを実証した
- [ ] CONTRIBUTING §4 共通 DoD

## レビュー観点

- `.gutconfig.json` の `should_exit` 忘れ（CI がハングする定番事故）
- `addons/gut/` が LFS/gitignore に食われていないか（全ファイルがコミットされているか）

## 実装しないこと（スコープ外）

- CI ワークフロー（#3）、実プロダクトコードのテスト（各機能 Issue で書く）
