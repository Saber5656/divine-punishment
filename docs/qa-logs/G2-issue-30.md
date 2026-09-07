# G2 — Issue #30: 再潜伏ループ

## 対象と結果

2026-09-07、実装担当 Codex が公式 Godot 4.3 (`77dcf97d8`) / macOS / Apple M4 / Vulkan Forward+ で検証した。対象は `be5cd1b6a86e50a7a9e4676963cc4e1cac14fe8c`、tree `6e87c99d6cf28d02ecb71e00277aed023b99ffa3`。先行実装は `84facbf6b9e68d623384dd45b89cfda2fe44723a`。

対象 tree のメカニクス実測は成功。可視画面を描画しながら 600.046 秒、通常の入力経路で発見 → 離脱 → 潜伏 → 捜索 → 帰投 → 再接近 → 背後必殺を 5 回完走した。人間の手動プレイ、Saihai facade role review、後続の統合 commit に対する検証とは称さない。今回の通常開発・レビュー手順は親タスクが記録した人間の指示に従う。

| 検証 | 結果 |
|---|---|
| 実時間 QA | UTC 03:49:10–03:59:10、600.046 秒、36,002 physics frames、time scale 1、終了 0 |
| 完走 | 5 回。最後の 6 回目は正常な Hidden/Search 中に 600 秒に達して終了。未完走分は成功回数に含めない |
| 実被弾からの離脱 | 2・4 周目で敵の攻撃を受け Player Combat に入ってから Shift により離脱成功 |
| 引っかかり・壁抜け | 5 回の壁接触後に移動再開、移動 timeout・壁通過検出・進行不能 0 件 |
| 接地 | 最低 player root Y = 0.0000937483 m。床は production capsule 中心原点に合わせた配置。床落下なし |
| runtime エラー | 最終 run の ERROR / WARNING 行なし |
| focused validation | 56/56 tests、312 assertions、終了 0 |
| repository full validation | 406/406 tests、3,292 assertions、終了 0 |

## 操作と観測

ジムは `src/levels/gym/restealth_gym.tscn`。production Player、EnemyBase、HideSpot、SearchPoint、PatrolPath を使用した。QA driver は通常の `Input.action_press/release` と `Input.parse_input_event` で移動・Shift・C・E・F を送る。ゲーム状態の直接設定、プレイヤーの teleport、AI 手動 tick、時計加速を使わず、描画と physics frame を待った。周回間のみ同じシーンを再起動した。

1. 正面で自然に視覚メーターが蓄積して Combat になるのを待つ。
2. 壁端を回り、退避地点へ走り E で Hidden に入る。偶数周は被弾を先に受ける。
3. 視線喪失から 3 秒、Search の 60 秒、持ち場までの実 navigation 帰投を待つ。
4. 初回はさらに Return 開始から 120 秒を待ち、残留警戒が ×1.5 から ×1.0 に戻るのを確認する。
5. E で退出し、敵背後へ接近して F。敵死亡と player の presentation 終了を確認する。
6. 走る・しゃがむを切り替えて壁沿いを移動し、壁に 1 秒押し続けた後、離れて移動できるか確認する。

初回は Return が 69.789 秒、残留終了が 189.795 秒（差 120.006 秒）。Return の実移動後に Unaware へ移り、残留は維持された。完走時刻は 199.669 / 293.168 / 386.529 / 480.008 / 573.398 秒。各周回の位置・状態・残留秒数は JSON とログに保存した。

これは経路を変えた入力 driver による実時間の操作検証であり、600 秒ずっと移動していたという意味ではない。捜索・残留の実時間待機を含む。確認した壁・移動経路で問題はなかったが、人間の自由な探索、別レベル、最終アート、G3、リリース QA の代替にはしない。

## 表示の一致

ジム HUD は production EnemyBrain の alert state / vigilance multiplier / remaining seconds をそのまま読む。完走画面では連鎖達成表示と ×1.5 / 111.2 秒が一致した。

別の短い可視 run では既存 `StealthDebugOverlay` を観測専用でジムに接続し、production PerceptionConfig と現在の meter / PlayerVisibility を公開 API から渡した。FOV 110、距離 15 m、meter 1.089555/3、V 0.621118 が一致し、`OVERLAY_MATCH=true`、終了 0。通常のジムにこの QA observer を常設したとは扱わない。スクリーンショットも目視確認し、手順・警戒表示が読めることを確認した。

## 実操作で見つかった不具合と修正

- 共通 EnemyBase の nav waypoint 許容が大きく、敵が壁角を切って止まった。production scene の waypoint 許容を 0.1 m、終端許容を 0.25 m にし、1 step の移動を次 waypoint までに制限した。ジムだけの設定上書きは使わない。
- EnemyCombat が取得済み target の Hidden 化を再確認せず、潜伏後も追跡・攻撃していた。target 取得時と追跡/攻撃前に既存の visibility exclusion を再確認する。退出後に通常の攻撃対象へ戻ることも回帰テストで確認した。
- 初期 QA driver の早期 class 解決による autoload 未初期化エラーは driver 側を修正した。これらの未完了・失敗 run を最終成功 run に合算しない。

## 統合時に残す確認点

並行する #36 は、既存 AssassinationResolver の local +Z 判定を player の正面 -Z に揃える修正を行う。この記録の commit は修正前で、driver の player yaw は PI 固定。敵背後 +Z への接近・F はその旧契約で成功した事実である。

統合担当は #36 適用後、player を敵背後 +Z に置き、player と敵をともに yaw 0（-Z 向き）として最終接近・F の実入力を再確認し、`test_restealth_loop.gd` の対応 fixture を整合する。旧方向の成功を修正後の成功へ転用しない。変更影響がない Search/Return の 600 秒全体を機械的に繰り返す必要はないが、統合後の所定検証は親タスクが実施する。

## 再実行と evidence

`GODOT_BIN` は公式 Godot 4.3 の実行ファイル。focused は設定ファイルの全ディレクトリ指定を無効にして対象を限定する。

```bash
"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_restealth_loop.gd,res://tests/unit/test_combat.gd,res://tests/unit/test_patrol_routines.gd,res://tests/unit/test_search_behavior.gd -gexit
GODOT_BIN="$GODOT_BIN" ./scripts/run_tests.sh
"$GODOT_BIN" --path . res://src/levels/gym/restealth_gym.tscn
# Evidence directory の driver を用いる場合:
"$GODOT_BIN" --path . -s "$ISSUE30_EVIDENCE/g2-runtime.gd"
```

full validation には既存 GUT orphan/ObjectDB・dummy mesh の警告が残るが、失敗テストと parse error は 0。検証後の intended tree と commit tree、および `git diff --binary --full-index` の SHA-256 を照合済み（patch `6f2c1a138e4b708d30e518ccf455148fd31fd0834f9953b045ef24328aabc36c`）。本 QA 文書追加は runtime behavior を変えない。

原本は親タスク `TSK-1351` の共有記録が参照する `issue30` evidence directory に保管する。公開ソースへ個人環境の絶対パス・生成 import・ログを混入しない。

| Artifact | SHA-256 |
|---|---|
| `g2-runtime.gd` | `66d4549031d23b904cbbdb489d4c1d357e6829376418f958a6e7bcc458bc5d00` |
| `g2-runtime.json` | `0dc8012fa02c989891381dc0a5223070094a317f2277eb14e91096e9800f8735` |
| `g2-runtime.log` | `e1d3785cf6f12bb8d33e501a8187c932845b693d1c27a5ca7cb22321ea393093` |
| `g2-fixes-focused.log` | `f2041f69903cdf282786ee7ebbb9cd0b69dae62a6dd5346e27ad478fe3bf4c3d` |
| `g2-fixes-full.log` | `bae0b2f3908a72cfb56f53a0fe91aaad9077c1f24b9ddcfeb78968403d6d4a23` |
| `g2-overlay.log` | `2823008c39df31c4474481693534f6dddf4800d6c985589c37da0f4049ac8d5c` |
| `g2-overlay.png` | `f07f1cf8b11b6dc06fcfeb535f7f1f32f25f712ea680ddb8c53fe69fe70a4c16` |
| `g2-cycle-5-completed.png` | `29deeee2436d5f4a01767b211d9bea59dbe010738d98fae1fa5ac94986d50714` |
| `g2-final.png` | `2f4278b43431be97c4f80802f1e7454982f25409921fd797425b8d7f45e3df06` |
