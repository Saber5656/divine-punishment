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
