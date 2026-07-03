# Divine Punishment — コンテンツ仕様・実装コントラクト

作成日: 2026-07-03
ステータス: Draft v1

本書は実装エージェント間の**契約**である。ここに定義されたスキーマ・シグナル・数値表は、変更する場合必ず本書を先に更新し PR で合意すること。数値は初期値（プレイテストで更新される。更新時は本書へ書き戻す）。

## 1. EventBus シグナル契約

```gdscript
# src/autoload/event_bus.gd — 全シグナルはここにのみ定義する
signal noise_emitted(event: NoiseEvent)
signal anomaly_registered(anomaly: Anomaly)        # 異常の発生（死体設置・消灯など）
signal anomaly_spotted(anomaly: Anomaly, by: Node) # 敵が異常を視認した
signal alert_changed(enemy: Node, from_state: int, to_state: int)  # AlertState enum
signal area_alert_changed(level: int)
signal enemy_killed(enemy: Node, method: String)   # method: "assassination"|"combat"
signal enemy_neutralized(enemy: Node, method: String) # "dart_sleep"|"knockout"|"restrained"
signal civilian_alarmed(civ: Node)
signal civilian_killed(civ: Node)
signal player_detected()                            # いずれかの敵が Combat に入った瞬間
signal light_extinguished(light: Node)
signal light_relit(light: Node)
signal mission_event(event_name: StringName, payload: Dictionary)
    # 予約 event_name: "objective_completed", "objective_changed", "checkpoint_reached",
    #   "target_killed", "hostage_rescued", "mission_failed", "escape_opened",
    #   "weather_changed", "firework_burst", "bell_rung", "boss_phase"
signal inner_monologue_requested(text_id: StringName)  # 暗殺直後の内語表示
```

### NoiseEvent / Anomaly（RefCounted）

| クラス | フィールド | 型 | 備考 |
|---|---|---|---|
| NoiseEvent | position | Vector3 | |
| | radius | float | m。壁遮蔽 1 枚ごとに実効半径 ×0.5 |
| | kind | enum NoiseKind { FOOTSTEP, LANDING, TOOL, DOOR, COMBAT, SCREAM, BELL, FIREWORK } | SCREAM/COMBAT は即・捜索 |
| | source | Node | 発生源（帰属判定用） |
| Anomaly | kind | enum AnomalyKind { CORPSE, RESTRAINED, LIGHT_OUT, DOOR_OPEN, PROP_FALLEN, FOOTPRINT, TRAP_DISARMED } | |
| | position / node | Vector3 / Node3D | |
| | severity | int 1–3 | 1=不審 2=捜索 3=捜索+エリア警戒+1（CORPSE=3, FOOTPRINT=1, LIGHT_OUT=1） |
| | expires_at | float | FOOTPRINT のみ有効（降雪 90 秒） |

## 2. Resource スキーマ（data/）

### 2.1 PlayerProfile（data/profiles/*.tres）

| フィールド | 型 | default 忍 の値 |
|---|---|---|
| move_speeds | Dictionary[Stance→float] | sneak 1.5 / walk 3.0 / sprint 6.0 / crawl 1.0 / swim 1.2 |
| noise_radii | Dictionary[Stance→float] | 1 / 4 / 12 / 1 / 0 |
| visibility_mods | Dictionary[Stance→float] | 0.6 / 1.0 / 1.3 / — / — |
| stationary_visibility_mod | float | 0.8 |
| breath_seconds | float | 20.0 |
| max_health | int | 3 |
| tool_slots | int | 3 |
| allowed_actions | Array[StringName] | 全アクション（M9 では mission 側で "sword","dart" 等を除外） |

### 2.2 ToolDefinition（data/tools/*.tres）

| フィールド | 型 | 小石 | 吹き矢 | 煙玉 | 鳴子 | 縄 |
|---|---|---|---|---|---|---|
| id | StringName | stone | dart | smoke | naruko | rope |
| display_name | String | 小石 | 吹き矢 | 煙玉 | 鳴子 | 縄 |
| default_count | int | 10 | 5 | 2 | 3 | 4 |
| is_projectile | bool | true | true | true | true | false |
| lethal | bool | false | false | false | false | false |
| effect_scene | PackedScene | noise 6m | 消灯 or 昏倒 20s | 視覚遮断 r5m 5s | noise 14m 持続 8s | 拘束（対昏倒体） |
| params | Dictionary | radius:6 | sleep:20 | radius:5, duration:5 | radius:14, duration:8 | restrain_time:2.0 |

- 当身（knockout）は忍具ではなくプレイヤーアクション（背後 1.2 m・非殺傷・昏倒 60 秒、縄で恒久化）

### 2.3 PerceptionConfig（data/tuning/perception.tres）

| フィールド | 足軽/侍 | 弓見張り | 敵忍 | 宗玄 |
|---|---|---|---|---|
| fov_degrees | 110 | 140 | 130 | 130 |
| view_distance_m | 15 | 25 | 18 | 20 |
| meter_gain_base | 2.0/s (@V=1.0, 至近, 中心視) | 2.0 | 3.0 | 3.5 |
| meter_decay | 0.5/s | 0.5 | 0.3 | 0.2 |
| suspicious_threshold / search / combat | 1.0 / 2.0 / 3.0（共通） | | | |
| hearing_multiplier | 1.0 | 1.0 | 1.5 | 1.5 |
| return_vigilance_mult / duration | 1.5 / 120 s（共通） | | | |
| can_climb | false | false | true | true |
| dart_immune | false | false | true | true |

距離減衰: `gain = meter_gain_base * V * clamp(1 - dist/view_distance, 0, 1)^2 * (中心視 1.0 / 周辺視 0.4)`。周辺視 = 視線から ±35° 超。

### 2.4 MissionDefinition（data/missions/m01.tres … m10.tres）

| フィールド | 型 | 備考 |
|---|---|---|
| id / title / level_scene | StringName / String / PackedScene | |
| objectives | Array[ObjectiveData] | {id, text, kind: KILL_TARGET/STEAL/RESCUE/ESCAPE/PROTECT, target_group} 順序付き |
| side_objective | ObjectiveData | null 可（M8） |
| tool_loadout | Dictionary[StringName→int] | ミッションごとの初期忍具。M9: {stone:10, smoke:2, rope:4} |
| forbidden_actions | Array[StringName] | M9: ["sword","assassinate_lethal","dart"] |
| kill_policy | enum { NORMAL, CIVILIAN_HEAVY, FORBIDDEN } | M3/M5: CIVILIAN_HEAVY, M9: FORBIDDEN |
| weather | enum { CLEAR, RAIN, SNOW, RAIN_THEN_CLEAR } | |
| par_time_minutes | float | 07-campaign §0.1 の表 |
| pre_cutscene / post_cutscene | CutsceneData | |
| inner_monologue_id | StringName | 暗殺直後の内語 |
| shura_rules | Dictionary | {nontarget_kill:+1, civilian_kill:+3, detection:+0.5} |

### 2.5 CutsceneData（data/narrative/cutscenes/*.tres）

| フィールド | 型 | 備考 |
|---|---|---|
| id | StringName | 例 "op", "m05_post", "epilogue_a" |
| slides | Array[SlideData] | {image: Texture2D, lines: Array[LineData], ambience: AudioStream, duration_auto: float} |
| LineData | {speaker: String("" =ナレーション), text: String, style: enum NARRATION/DIALOGUE/INNER} | テキストは 06-narrative.md の確定台詞を転記 |
| skippable | bool | 全て true（初回視聴も可） |

### 2.6 HideoutScene（data/narrative/hideout/h1.tres … h8.tres）

| フィールド | 型 | 備考 |
|---|---|---|
| id / background | StringName / Texture2D | |
| shura_threshold | int | H1:2, H2:4, H3:6, H4:8, H5:—(共通), H6:10, H7:—, H8:— |
| lines_calm / lines_blood | Array[LineData] | `shura <= threshold` → calm。閾値なしは calm のみ使用 |

### 2.7 WeatherConfig（data/tuning/weather.tres）

| 天候 | player_noise_mult | enemy_view_mult | 特殊 |
|---|---|---|---|
| CLEAR | 1.0 | 1.0 | — |
| RAIN | 0.5 | 0.8 | 屋外 LightSource のうち rain_fragile=true は消灯状態で開始 |
| SNOW | 1.0 | 1.0 | 足跡 Anomaly 生成（間隔 0.8 m・寿命 90 s・岩/倒木/氷 surface では生成なし） |

### 2.8 ScoringConfig（data/tuning/scoring.tres）

02-game-design.md §7 の配点 + キャンペーン追加分:

| 追加項目 | 値 |
|---|---|
| civilian_kill_penalty | −10/人 |
| side_objective_bonus | +5 |
| M9 特例 | 「一撃」→ 当身成功数 ≥ 敵接触数の 80% で満点 |
| M10 特例 | 「疾風」項目なし（配点を影 walker へ +15 振替） |
| epilogue_a_condition | 累計 shura ≤ 12（M10 リザルト時に判定） |

## 3. プレイヤー状態機械 遷移表（契約）

| From \ 入力 | 移動 | しゃがみ | 走り | 壁際+張付 | 登攀縁 | 梁端 | 床下口 | 水面 | HideSpot | 必殺成立+入力 | 被弾0 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ground | Ground | Crouch | Sprint | WallCling | Climb | — | Crawl | Swim | Hidden | Assassinate | Dead |
| Crouch | Crouch | Ground | Sprint | WallCling | Climb | — | Crawl | Swim | Hidden | Assassinate | Dead |
| WallCling | 壁沿い移動 | — | 解除→Ground | — | Climb | — | — | — | — | Assassinate(corner) | Dead |
| Climb | 上下 | — | — | — | 頂上→Ground/Beam | Beam | — | — | — | — | Dead |
| Beam | 梁上移動 | — | — | — | — | 降下→Ground | — | — | — | Assassinate(above) | Dead |
| Crawl | 匍匐 | — | — | — | — | — | 出口→Crouch | — | — | Assassinate(below) | Dead |
| Swim | 水泳 | 潜行 | — | — | 岸→Ground | — | — | — | — | — | Dead |
| Hidden | — | — | — | — | — | — | — | — | 出る→Crouch | — | Dead |
| Carry(死体/拘束体) | 低速移動 | 可 | 不可 | 不可 | 不可 | 不可 | 可 | 可(沈める) | 格納→Crouch | 不可 | Dead |
| Combat | 移動 | — | — | — | — | — | — | — | — | — | Dead |
| Escort(千代同行, M9) | 移動 | 可 | 不可 | 不可 | 不可 | 不可 | 可 | 不可 | 2人用のみ | — | Dead |

Combat への遷移: いずれかの敵が Combat 状態でプレイヤーを攻撃対象にした時、抜刀入力で。M9 は Combat 遷移なし（逃走のみ）。

## 4. 入力マップ（InputMap 契約）

| アクション名 | KBM | パッド |
|---|---|---|
| move_* | WASD | 左スティック |
| camera_* | マウス | 右スティック |
| stance_toggle | C | B/○ |
| sprint | Shift | L3 |
| interact | E | A/× |
| assassinate | F（プロンプト時） | X/□ |
| tool_use / tool_cycle | 左クリック / Q or ホイール | RT / RB |
| aim | 右クリック | LT |
| peek | 張り付き中 A/D 押し込み | 張り付き中スティック |
| attack / parry / dodge | 左click / 右click / Space（Combat時） | X / LB / A |
| pause | Esc | Start |

## 5. セーブデータスキーマ（user://save.json）

```json
{
  "version": 2,
  "campaign": {
    "unlocked_mission": 7,
    "shura": 9,
    "total_nontarget_kills": 6,
    "total_detections": 5,
    "mission_results": { "m01": {"rank": "皆伝", "score": 93, "flags": {"undetected": true, "no_body_found": true, "one_strike": true, "swift": false, "side": true}}, "...": {} },
    "seen_cutscenes": ["op", "m01_pre"]
  },
  "settings": { "volume_master": 1.0, "volume_bgm": 0.8, "volume_se": 1.0, "sensitivity": 0.5, "quality_preset": "high", "input_overrides": {}, "locale": "ja" },
  "checkpoint": null
}
```

- version フィールドでマイグレーション。checkpoint はミッション中断時のみ非 null（位置・忍具残・エリア警戒・目標進行・ナラティブ変数のスナップショット）

## 6. 敵ステータス表

| 敵 | HP(斬撃) | 攻撃力 | 特記 |
|---|---|---|---|
| 足軽 / 侍 / 同心 / 供侍 / 城兵 | 3 | 1 | 基本型。城兵(M9)は捕縛行動のみ |
| 弓見張り | 2 | 1(遠) | 高所定点。矢は回避可能な弾速 |
| 僧兵 | 4 | 1 | 雨天時 視界 −20% 追加（傘） |
| 提灯持ち | 3 | 1 | 半径 6 m の移動 LightSource 携行 |
| 護衛 | 4 | 1 | 標的随伴。標的死亡時 即 Combat |
| 鉄仙坊(M4) | 8 | 2 | 受け流し必須。必殺は可能（=ステルスなら平等） |
| 下忍 | 3 | 1 | |
| 敵忍 | 4 | 1 | PerceptionConfig 敵忍列。撒菱使用 |
| 鴉羽(M7) | 5 | 2 | 敵忍強化。頭屋敷では護衛 0（一騎打ちの誇り） |
| 宗玄(M10) | 必殺×3 | 必殺(背後)2回で敗北 | §07 M10 仕様 |

## 7. アニメーション必要一覧（調達・制作リスト）

| 対象 | クリップ |
|---|---|
| プレイヤー | idle/walk/run/crouch系一式, 壁張付, 登攀, 梁バランス移動, 匍匐, 泳ぎ/潜行, 担ぎ移動, 抜刀・斬撃×3・受け流し・回避, 被弾, 死亡, **必殺×4 文脈（背後/頭上/床下/角）**, 必殺ためらい版(M6), 当身, 拘束, 消灯所作, 千代の手を引く(M9) |
| 汎用敵 | idle/巡回歩行/走り, 不審(凝視・首かしげ), 捜索(かがんで確認), 戦闘(斬撃×2・構え・被弾・死亡), 昏倒/覚醒, 被必殺×4(プレイヤー側と対), 再点灯所作, 引きずられ(拘束) |
| 敵忍 | 上記 + 登攀/屋根走り/撒菱投げ |
| 千代 | 待機/追従歩行/かがみ/怯え |
| 宗玄 | 敵忍セット + 決闘構え/煙玉離脱/敗北 |

## 8. アセット調達リスト（ライセンス台帳 docs/asset-licenses.md に記録）

| カテゴリ | 内容 | 数量目安 |
|---|---|---|
| 建築モジュール | 和風: 屋敷/寺/城/湊/里/祭り屋台/峠(雪) | 環境セット 7 種 |
| キャラモデル | 忍(主人公/敵忍色違い), 侍/足軽系 ×4, 僧兵, 町人 ×4, 少女, 商人, 貴人 ×2 | 15 体 |
| カットシーン画 | 浮世絵風静止画（生成 or 発注、画風ガイド 09-ui §7） | 約 70 枚 |
| BGM | 静寂/不穏/戦闘レイヤー ×3 セット（通常/祭り/最終）+ エピローグ曲 | 10 曲 |
| SE | 足音(材質5)/忍具/戸/鐘/花火/祭囃子/雨/雪風/水 | 60 点 |

## 9. パフォーマンス契約（追加）

- 民間人 12 体は簡易知覚（プレイヤー視認チェックのみ・2 Hz）
- 雪足跡は最大 60 個のリングバッファ（超過分は古い順に消滅）
- 群衆は GPU インスタンシング + 5 体単位の簡易ルート移動
