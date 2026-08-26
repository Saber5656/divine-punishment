# Issue #3: GitHub Actions CI（テスト + 3 OS エクスポート）

- Milestone: M0 / ラベル: area:infra, type:feature
- 依存: #2
- ゲート: G1

## 目的

push / PR で GUT が自動実行され、main への push で Windows / macOS / Linux のビルド artifact が出る CI を作る。G1 ゲートの機械部分がこれで成立する。macOS は Godot 4.3 公式テンプレートの既定である Universal 2（x86_64 + arm64）を維持し、host OS に依存しない texture import 設定で clean CI export を成立させる。

## 読むべき仕様（読む順）

1. docs/03-technical-design.md §9 — CI 方針
2. docs/instructions/M0/issue-02.md — テスト実行コマンド（CI はこれと同一コマンドを使う）
3. Godot 4.3 `platform/macos/export/export_plugin.cpp` の Universal/arm64 validation — Universal 2 は S3TC/BPTC と ETC2/ASTC の両 import を必要とする

## 変更対象パス

| パス | 種別 | 内容 |
|---|---|---|
| `.github/workflows/ci.yml` | 新規 | test ジョブ（push/PR）+ export ジョブ（main のみ） |
| `export_presets.cfg` | 新規 | Windows Desktop / macOS / Linux の 3 プリセット |
| `project.godot` | 変更 | Universal/arm64 macOS export 用の ETC2/ASTC texture import override |
| `README.md` | 変更 | CI バッジ追加 |

## 実装手順

1. Godot 4.3 の headless 実行環境は、**Godot 公式ビルドをダウンロードする方式**で構築する（サードパーティ action へのバージョン追従依存を避ける）。バージョンは #1 で記録した 4.3.x と完全一致させ、URL を workflow 内の env にまとめる
2. test ジョブ: ubuntu-latest → Godot 取得 → `--headless --import`（初回インポート）→ `./scripts/run_tests.sh`
3. export ジョブ（`if: github.ref == 'refs/heads/main'`）:
   - export templates（同バージョン）を取得して配置
   - `godot --headless --export-release "Windows Desktop" build/windows/dp.exe` 等を 3 OS 分
   - `actions/upload-artifact` で `build/` を保存（保持 14 日）
4. `project.godot` の `[rendering]` に `textures/vram_compression/import_etc2_astc=true` を設定する。Linux CI host が ETC2/ASTC を自動選択しなくても Universal 2 の arm64 側 texture を clean import できるようにする。既存の `renderer/rendering_method="forward_plus"` は変更しない
5. `export_presets.cfg` は 3 プリセットとも `binary_format/embed_pck=true`（Linux/Win）、macOS は zip。macOS の architecture は Godot 4.3 の既定 `universal` を維持する。x86_64 固定で validation を回避しない。署名関連は空欄のまま（リリース署名は #85）
6. 初回実装では PR で意図的にテストを壊す commit → CI が赤くなることを確認 → revert（確認結果を PR に記載）。2026-08-26 corrective では実際の main run `32822013495` / Export job `97722095063` が macOS export の非 0 終了を既に実証しているため、同じ negative evidence を再利用し、修正後の exact tree で成功へ反転することを確認する
7. ブランチ保護（main への直 push 禁止・CI 必須化）は **リポジトリ設定のため PO に依頼する**（PR 本文に依頼文を書く。エージェントが設定変更しない）

## 検証手順

Godot editor と export templates はともに `4.3-stable` / `4.3.stable` を使い、task 専用の clean worktree で実行する。既存 import cache を流用しない。

```bash
export GODOT_BIN="/absolute/path/to/Godot-4.3"
"$GODOT_BIN" --version                     # 4.3.stable.official を含む
test ! -e .godot                            # clean import の前提
mkdir -p build/windows build/macos build/linux
"$GODOT_BIN" --headless --import --path .

GODOT_BIN="$GODOT_BIN" ./scripts/run_tests.sh

"$GODOT_BIN" --headless --path . --export-release "Windows Desktop" build/windows/dp.exe
"$GODOT_BIN" --headless --path . --export-release "macOS" build/macos/dp.zip
"$GODOT_BIN" --headless --path . --export-release "Linux/X11" build/linux/dp.x86_64

test -s build/windows/dp.exe
test -s build/macos/dp.zip
test -s build/linux/dp.x86_64
unzip -t build/macos/dp.zip

rm -rf /tmp/dp-issue-3-macos-check
mkdir -p /tmp/dp-issue-3-macos-check
unzip -q build/macos/dp.zip -d /tmp/dp-issue-3-macos-check
MAC_BIN="$(find /tmp/dp-issue-3-macos-check -type f -path '*/Contents/MacOS/*' -print -quit)"
test -n "$MAC_BIN"
lipo -info "$MAC_BIN" | tee /tmp/dp-issue-3-macos-architectures.txt
grep -q 'x86_64' /tmp/dp-issue-3-macos-architectures.txt
grep -q 'arm64' /tmp/dp-issue-3-macos-architectures.txt

git diff --check
git status --short                         # .godot/, build/, *.uid, *.import を task diff に含めない
```

- PR 上: exact head の test ジョブが緑で、full GUT の `Passing == Tests`、parse / compile error なしを確認する。現 workflow の Export job は main 限定なので、上記 local exact-tree export log と artifact digest を PR/Vault に記録する
- main マージ後: actual merge SHA の Export job が terminal success で、3 OS artifact がダウンロードでき、Linux 版が Ubuntu runner で `--headless --quit` 相当で起動することを確認する。この integrated validation が完了するまで同 repository の次の merge を行わない

## 完了条件（DoD）

- [ ] Issue #3 受け入れ条件 全チェック
- [ ] CI の Godot バージョンがプロジェクトと一致（env で一元管理）
- [ ] clean import から Windows / macOS Universal 2 / Linux の 3 export がすべて成功し、macOS binary に x86_64 と arm64 の両方が含まれる
- [ ] actual merge SHA の main Export job と 3 OS artifact を確認し、結果を Issue / PR / Vault に記録した
- [ ] 赤くなることの実証を行った
- [ ] CONTRIBUTING §4 共通 DoD

## レビュー観点

- `--import` の事前実行漏れ（初回 CI だけ落ちる定番事故）
- export templates のバージョン不一致
- Linux host で ETC2/ASTC import を有効にせず Universal/arm64 macOS export が失敗しないか
- macOS preset を x86_64 に狭めて Apple Silicon native support を失っていないか
- stale `.godot/imported/` が設定不足を隠していないか
- artifact に `.godot/` 等のゴミが入っていないか

## 実装しないこと（スコープ外）

- リリース署名・Steam アップロード（#85）、ブランチ保護の実設定（PO 作業）
- renderer、texture asset、export preset architecture、CI trigger/job 構成の変更
