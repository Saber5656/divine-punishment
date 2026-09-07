# Issue #35: MissionDirector（目標・評価カウンタ・リザルト生成）

- Milestone: M6 / area:ui
- 起点: main `f5c88d7bf4e1e1fb8a65c5188149246dc0e0a17c`
- 依存: #5 の autoload / Resource、#26 の enemy_killed、#28 の corpse anomaly は既存実装を使用する。#34 の TargetNpc.target_killed も接続先として使用する
- 既存実装は遡及的ベースライン。本指示書は今回以後の追加変更を対象とする

## 目的と受け入れ条件

| AC | 実装・検証 |
|---|---|
| 暗殺→脱出の目標進行 | 順序付き ObjectiveData を現在IDに一致する完了だけで進める。target_killed / enemy_killed から該当KILL_TARGETを完了し、ESCAPE開始を通知。最後の完了後は current_objective=null。重複・順序外完了で飛ばさない |
| scoring.tresによる皆伝〜初伝 | 標準4項目、非標的殺害の減点上限、民間人減点、副目標bonusをScoringConfigから計算。rank閾値境界と独自configをテスト |
| 集計logicテスト | 実EnemyBase/TargetNpcの暗殺・戦闘イベント、発見、死体重複、時間、停止・再開、目標変更通知を確認 |
| docs08§10準拠 | 公開APIを保持。EventBusを介し、検知の二重加算を除去。scene/collision/FSM遷移の変更なし |

## 読む仕様と担当範囲

1. docs/02-game-design.md §7（標準評価）
2. docs/08-content-specs.md §1、§2.4、§2.8、§10.1、§10.4（イベント、Resource、API、検知所有者）
3. src/autoload/mission_director.gd、MissionStats、TargetNpc、EnemyBase/EnemyCombat、EnemyBrainの既存イベント

| Path | 今回の変更 |
|---|---|
| docs/instructions/M6/issue-35.md | 将来向け指示書 |
| docs/08-content-specs.md | イベントpayload・統計所有者・副目標結果の説明を実装前に具体化 |
| src/autoload/mission_director.gd | 目標遷移、イベント購読、実行中の時間・集計、結果生成 |
| src/core/mission/mission_stats.gd | 副目標達成状態 |
| src/enemies/enemy_brain.gd | _on_combat_enter の統計直接加算だけを除去。player_detectedとarea alertは保持 |
| tests/unit/test_mission_director.gd | AC・境界・実ノード連携の回帰テスト |

#31のRetryFlow/CheckpointArea、#30のRETURN処理とは担当を分離する。MissionDirectorのsnapshot/restore APIが必要な場合は親を通して合意する。

## 実装手順

1. 既存start_mission/complete_objective/fail_mission/current_objective/stats/build_result/compute_scoreの署名を保つ。startはカウンタ・重複検出・目標・結果状態をresetする
2. active中だけ時間と評価を加算し、failureまたは最後の目標達成で停止する。副目標IDの完了は主目標indexを進めず一度だけbonusを付ける
3. target_groupに該当する敵を標的として識別し、暗殺/戦闘の両イベント経路を同一個体identityで重複排除する。一撃は実際に標的を暗殺して初めて成立し、戦闘撃破を混ぜると不成立
4. EnemyBrainはCOMBAT突入時のplayer_detectedを発火するのみとし、MissionDirectorがdetectionsを加算する。既存のcorpse anomalyの個体重複排除とarea alert上昇を保持する
5. score/rankの数値はTuning.scoring()のみから取得する。結果には達成項目とfailure/completed状態を含める。build_result呼出は統計を変更しない
6. 無関係なイベント、開始前・終了後イベント、重複完了、無効deltaで加算や目標skipが発生しないことを確認する

## 検証

```bash
export GODOT_BIN=/Users/takagiyasushi/.codex/task-evidence/divine-resume-20260907/godot43/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --version
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_mission_director.gd -gexit
GODOT_BIN="$GODOT_BIN" bash ./scripts/run_tests.sh
git diff --check
```

対象テストでは実TargetNpcとEnemyBaseを生成し、暗殺でESCAPEへ、正しい脱出IDの完了で最終結果へ進める。実EnemyBrainのCOMBAT突入は検知を一度だけ加算する。結果UI・プレイ用mission資産は#36/#38/#40の担当とし、今回UIの手動確認済みとは報告しない。

## 未確定のキャンペーン評価とscope外

docs08にはM9の敵接触数に対する当身成功率、M10の時間配点振替が定義されている。親と対応範囲を確認し、#35では標準ミッションの評価・副目標を完成させる。M9/M10固有の接触成立・重複・分母0・宗玄以外の検知イベント契約は、該当キャンペーンIssueで定義・実装する。全Issue対応から除外せず、未使用の推測入力を追加しない。docs08とPRにこの限界を明記し、標準評価の成功を特例の実装完了へ読み替えない。

セーブ/画面遷移、レベル配置、checkpoint復元、当身・拘束/Boss本体、アート、点数の再調整は対象外。通常の追加reviewは不要。focused/full結果、commit、未達項目は親がVaultへ記録しpush/PRを担当する。
