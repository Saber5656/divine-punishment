# Issue #3: GitHub Actions CI（テスト + 3 OS エクスポート）

- Milestone: M0 / ラベル: area:infra, type:feature
- 依存: #2
- ゲート: G1

## 目的

push / PR で GUT が自動実行され、main への push で Windows / macOS / Linux のビルド artifact が出る CI を作る。G1 ゲートの機械部分がこれで成立する。

## 読むべき仕様（読む順）

1. docs/03-technical-design.md §9 — CI 方針
2. docs/instructions/M0/issue-02.md — テスト実行コマンド（CI はこれと同一コマンドを使う）

## 変更対象パス

| パス | 種別 | 内容 |
|---|---|---|
| `.github/workflows/ci.yml` | 新規 | test ジョブ（push/PR）+ export ジョブ（main のみ） |
| `export_presets.cfg` | 新規 | Windows Desktop / macOS / Linux の 3 プリセット |
| `README.md` | 変更 | CI バッジ追加 |

## 実装手順

1. Godot 4.3 の headless 実行環境は、**Godot 公式ビルドをダウンロードする方式**で構築する（サードパーティ action へのバージョン追従依存を避ける）。バージョンは #1 で記録した 4.3.x と完全一致させ、URL を workflow 内の env にまとめる
2. test ジョブ: ubuntu-latest → Godot 取得 → `--headless --import`（初回インポート）→ `./scripts/run_tests.sh`
3. export ジョブ（`if: github.ref == 'refs/heads/main'`）:
   - export templates（同バージョン）を取得して配置
   - `godot --headless --export-release "Windows Desktop" build/windows/dp.exe` 等を 3 OS 分
   - `actions/upload-artifact` で `build/` を保存（保持 14 日）
4. `export_presets.cfg` は 3 プリセットとも `binary_format/embed_pck=true`（Linux/Win）、macOS は zip。署名関連は空欄のまま（リリース署名は #85）
5. PR で意図的にテストを壊す commit → CI が赤くなることを確認 → revert（確認結果を PR に記載）
6. ブランチ保護（main への直 push 禁止・CI 必須化）は **リポジトリ設定のため PO に依頼する**（PR 本文に依頼文を書く。エージェントが設定変更しない）

## 検証手順

- PR 上: test ジョブが走り緑になる / 意図的破壊で赤になる（スクリーンショット添付）
- main マージ後: 3 OS の artifact がダウンロードでき、Linux 版が `--headless --quit` 相当で起動する（可能なら実機 1 OS で起動確認）

## 完了条件（DoD）

- [ ] Issue #3 受け入れ条件 全チェック
- [ ] CI の Godot バージョンがプロジェクトと一致（env で一元管理）
- [ ] 赤くなることの実証を行った
- [ ] CONTRIBUTING §4 共通 DoD

## レビュー観点

- `--import` の事前実行漏れ（初回 CI だけ落ちる定番事故）
- export templates のバージョン不一致
- artifact に `.godot/` 等のゴミが入っていないか

## 実装しないこと（スコープ外）

- リリース署名・Steam アップロード（#85）、ブランチ保護の実設定（PO 作業）
