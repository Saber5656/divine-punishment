# Issue #30: Disengage → Re-Stealth Loop

- Milestone: M4。依存: #23、#29。開始 base: `f5c88d7`（#138/#136 統合後）。
- 本書は今回の修正・統合検証に先行する指示書。既存 EnemyBrain/Perception の実装は過去の成果であり、本書の事前承認に遡及しない。
- 今回は人間の指示に従い Codex primary が開発フローを調整する。旧 Saihai runtime・累積レビュー・再承認 gate は要求しない。ゲーム仕様と focused/full validation、PR CI は維持する。

## 目的と正本

発見されても遮蔽物で視線を切り、隠れて敵の捜索をやり過ごし、再び背後必殺を狙える連鎖を完成する。`docs/02-game-design.md` §4.1/§6、`docs/08-content-specs.md` §2.3/§3/§10.4 を正本とする。視線喪失 3 秒で Combat → Searching、捜索 60 秒で Return、実際の持ち場到着で Unaware。Return 開始から既存 PerceptionConfig の 120 秒間、視覚蓄積は ×1.5。

## 変更対象

| Path | 内容 |
|---|---|
| `src/enemies/enemy_brain.gd` | 帰投時の実移動と、低優先度の音が視線喪失タイマーを停止しない処理 |
| `src/enemies/enemy_base.gd` / `.tscn` | 実操作で見つかった共通 nav waypoint の角切りを防ぐ。既定 waypoint 許容距離 0.1 m、最終到達許容 0.25 m、1 step の移動を次 waypoint までの距離で制限する |
| `src/enemies/enemy_combat.gd` | 実操作で見つかった Hidden への追跡・攻撃を修正。既存 `is_visibility_excluded()` を target 取得時と攻撃/追跡直前に再確認する |
| `src/player/player_controller.gd` | Combat の入力分岐だけ。C で既存 Crouch、Shift で既存 Sprint へ離脱。攻撃・受け流し・回避動作中は離脱しない |
| `src/player/player_combat.gd` | `can_disengage()` で startup/active/recovery/parry/dodge の動作終了を公開する。ダメージや死亡処理は不変 |
| `src/levels/gym/restealth_gym.gd` / `.tscn` | production Player/EnemyBase/HideSpot/SearchPoint/PatrolPath を組み合わせる専用検証ジム。状態・残留時間を画面表示 |
| `tests/integration/test_restealth_loop.gd` | 実 physics/視覚 ray/Hidden/Navigation/AssassinationResolver を通す連鎖と境界検証 |
| `tests/unit/test_enemy_brain.gd` | 音による視線喪失タイマー停止の回帰検証 |

## 実装契約

1. Return は既存 `advance_navigation` を既存の bounded delta/speed で呼ぶ。空 navmap・到達不能・壁衝突時は teleport や到着偽装をしない。実距離/移動結果で到着を判定し、relight が残る場合は早期 Unaware を禁止する。
2. Combat 中、視認/被弾以外の弱い音刺激を受け続けても、視線喪失 3 秒は経過する。視認の回復や高優先度の被弾は従来どおりタイマーをリセットする。1 physics tick に 1 回だけ進める。
3. 既存調整値、刺激順位、Hidden の近距離視認拒否、必殺の Combat/視認拒否は維持する。残留 ×1.5 は actual perception meter でも検証し、120 秒後に ×1.0 へ戻る。
4. ジムは独立 scene とし、既存 movement gym/main の構成は変更しない。静的遮蔽壁、退避地点、navmesh、持ち場と捜索地点、既存 production scene のプレイヤーと足軽を配置する。発見回数と警戒段階・残留時間を表示し、手動で連鎖を再現できる。
5. 被弾・抜刀後の Player Combat が入力を永久遮断しない。既存 C/Shift 入力を使用し、攻撃（回復中を含む）・parry・dodge 中は待つ。Sprint は Ground を復帰先として記録し、Shift を離すと Ground に戻る。#31 の死亡/checkpointコードは変更しない（親と所有境界を合意済み）。
6. 実経過 QA で確認した壁角停止はジム限定の workaround にしない。production EnemyBase の NavigationAgent 既定値を修正し、同じ production instance が遮蔽壁を回って追跡・帰投できることを確かめる。大きな bounded delta でも waypoint を行き過ぎない。空 navmap では既存どおり動かない。
7. 敵が既に持つ target が Hidden になった場合、その正確な座標を Combat の追跡/攻撃に使わない。敵側の sight-loss/Search と HideSpot の発見・潜伏解除の正本は従来どおり Brain/Perception。退出後は通常の被攻撃対象へ戻る。

## 検証・受け入れ条件

| AC | 検証 |
|---|---|
| LOS 遮断＋隠れる → Search | production perception の閾値による Combat、実壁で ray 遮断、接地後 `try_enter_hide_spot`、3 秒後 Search。可視 override/force_state で連鎖を成立させない |
| 帰投後の警戒残置 | SearchPoint への実移動、60 秒捜索、持ち場への navigation 帰投、到着後も ×1.5、時限後 ×1.0。空 navmap では Return を維持 |
| ジムの全連鎖 | 同一ジムの同一敵で detected → disengage → Hidden → Search → Return → Unaware → 隠れ場所退出 → 背後 overlap → resolver.confirm → 敵死亡と presentation 完了 |

Godot は公式 4.3。`GODOT_BIN` に実行ファイルを設定して以下を実施する。

```bash
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_restealth_loop.gd,res://tests/unit/test_enemy_brain.gd -gexit
GODOT_BIN="$GODOT_BIN" ./scripts/run_tests.sh
git diff --check
"$GODOT_BIN" --path . res://src/levels/gym/restealth_gym.tscn
```

手動: WASD/マウスで移動・視点、C でしゃがむ、Shift で走る、E で隠れる/退出、F で必殺。正面で発見された後、壁の背後の退避地点へ移動して E。捜索終了と持ち場への帰投を待ち、E で出て敵の背後へ回り F。画面の警戒表示と残留時間を確認する。自動統合検証と人間の手動プレイ結果は混同しない。

## Scope 外

死亡/checkpoint/retry（#31）、MissionDirector（#35）、新規 combat/stealth の数値変更、既存アセットの削除、外部アセット取得、GitHub/Vault への変更は担当しない。生成された import/uid/build artifact は commit しない。親が task 記録、push/PR/CI/merge と統合後検証を担当する。
