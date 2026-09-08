# ミッション内の世界状態をチェックポイントへ追加する

Issue #40 が導入し、#38 のチュートリアルも利用する共通 API。プレイヤーの既存 `CheckpointSnapshot` に JSON-compatible な辞書を追加する。生きた Node / Resource / Vector3 / instance ID を保存しない。

| API | 契約 |
|---|---|
| `MissionDirector.attach_mission_scene(scene, definition)` | シーン実体が run を一度取得する。SceneDirector が開始済みなら最初の取得は値を保持し、次の新しいシーンでは前回の進行を初期化する |
| `active_mission_id()` | 現在の定義 ID。これだけで新規シーンと復元を区別しない |
| `capture_checkpoint_state(entities)` | `entities` は stable な文字列 ID → 生存 Node。目標・スコア・進行状態と、kill/neutralize/corpse の重複防止集合を stable ID へ変換する |
| `checkpoint_state_is_valid(value, entities)` | 同じ mission、有限値・型・範囲・既知 ID・completed/running の整合を確認する |
| `restore_checkpoint_state(value, entities)` | 全検査に成功してから復元し、現在の目標通知を再送する。kill event は再発行しない |
| `MissionNpcSnapshot.capture(npc)` | 位置配列・yaw、Brain の警戒/行動時刻/行動地点/潜伏後警戒、Combat の体力/回復、知覚 meter を保存する |
| `MissionNpcSnapshot.is_valid(value, npc)` | 全成分の検査。無効値なら位置やスコアを一部だけ書き換えない |
| `MissionNpcSnapshot.restore(value, npc)` | 新しい scene の production NPC に適用する。標的の既報告死亡もイベントなしで戻す |

レベル側は `mission_world` 等の独自 namespace に NPC 辞書と `MissionDirector` の辞書、学習進行・光源・門・収納場所などをまとめる。`checkpoint_reached` を受けた直後に `GameState.checkpoint_ref` へ補完する。復元前にはレベル固有の目標と生死の整合、NPC ID の完全性、時刻で切り替わる行動経路を確認する。

`PlayerRetryFlow` のプレイヤー復元が成功した後、scene root または `Mission` child の `restore_checkpoint_world(snapshot) -> bool` から適用する。途中失敗なら復元エラーを返し、成功と扱わない。body storage はレベルが stable HideSpot ID を解決して既存 `begin_storage()` を使用する。nav の実行中 path cache と瞬間的な視認/刺激は保存せず、復元後に実世界から再計算する。

初期実装は 2026-09-07、2026-09-08 の再開後に TDD で新規シーンの前回状態残留、矛盾した完了フラグ、存在しない地点、体力と死亡フラグの不整合を再現・修正した。`test_mission_world_checkpoint.gd` はこの契約の回帰テストであり、実操作の所要時間や各ミッションの G3 合格を証明するものではない。

## 護衛の死亡反応（Issue #40）

標的死亡時の護衛のCOMBAT移行とエリア警戒は保持する。視認していないプレイヤーを発見回数に加えず、最初の視認または直接接触時に一度だけ通知する。`brain.combat_detection_pending` とNPCの `escort_reacted` はboolとして保存する。既存snapshotで省略された場合はfalseとし、復元時に標的死亡反応や発見通知を再発行しない。護衛は一度反応した後、視線を失えば通常のSearchへ移行できる。

護衛の未視認の警戒中はEnemyCombatが全プレイヤー検索でtargetを取得しない。援軍への警戒通知は行い、視認または直接攻撃でcontactが確定した後に通常の追跡/攻撃を再開する。

## Playerの保存姿勢

CheckpointSnapshot version 1はoptional `posture`（Ground/Crouch/Crawlspace）を持つ。旧snapshotの省略はGround。任意の文字列は拒否し、復元先にそのcapsuleが収まることを確認してから姿勢・位置・忍具・警戒を変更する。Crawlspaceは移動後に入口依存を解放する既存契約と同じ、現在設定に結びつくcrawl状態を再構築する。

必殺演出・登攀・泳ぎ等の途中状態は新規captureを拒否し、既存checkpointを保持する。屋敷の標的kill checkpointは演出から安定姿勢へ戻ってから保存する。実C経路では床下必殺後のpause→再開でCrawlspace・標的死亡・ESCAPEが保持され、そのまま水路脱出できることを確認する。
