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

## 10. 実装補遺（API・シーンツリー・レイヤー・FSM 擬似コード）

複数エージェントの並行実装で規約が食い違わないための補遺。§1〜§6 と矛盾した場合は**発見した側が PR で本書を修正して合意を取る**（黙って実装側で解決しない）。

### 10.0 共通 enum（src/core/enums.gd に集約）

```gdscript
enum AlertState { UNAWARE = 0, SUSPICIOUS = 1, SEARCHING = 2, COMBAT = 3, RETURN = 4 }
enum Stance { SNEAK, WALK, SPRINT, CRAWL, SWIM }   # PlayerProfile の Dictionary キー
enum StimulusKind { VISUAL, NOISE, ANOMALY, DAMAGE }
```

`EventBus.alert_changed(enemy, from_state, to_state)` の int は `AlertState` の値である（§1 と対応）。

### 10.1 主要クラス API シグネチャ

GDScript・全メソッド型付き必須。「pure」= static かつ副作用なし（GUT ユニットテスト対象、NFR-05）。private（`_` 接頭辞）はここでは規定しない。

```gdscript
# ── src/player/player_state_machine.gd  (Node, player.tscn 直下 "StateMachine")
class_name PlayerStateMachine
signal state_changed(from: StringName, to: StringName)
func current_state() -> StringName                    # §3 の状態名: &"Ground" 等
func can_enter(next: StringName) -> bool              # §3 遷移表に従う
func change_state(next: StringName, ctx: Dictionary = {}) -> bool  # 不正遷移は false・状態不変
func stance() -> Enums.Stance                         # Ground=WALK, Crouch/Hidden=SNEAK 等の写像
func movement_params() -> Dictionary                  # PlayerProfile から現状態の {speed, noise_radius, visibility_mod}

# ── src/stealth/player_visibility.gd  (Node, player.tscn 直下 "Visibility")
class_name PlayerVisibility
signal visibility_changed(v: float)
func visibility() -> float                            # 最後に計算した V ∈ [0,1]
func recompute() -> float                             # 内部 10 Hz タイマーが呼ぶ。テストから直接呼び可
static func light_contribution(dist: float, gameplay_radius: float, occluded: bool) -> float   # pure
static func combine(light_sum: float, stance_mod: float, move_mod: float, cover_mod: float) -> float  # pure, §GDD 2.1

# ── src/player/assassination_resolver.gd  (Node, player.tscn 直下 "AssassinationResolver")
class_name AssassinationResolver
signal prompt_changed(enemy: EnemyBase, context: StringName)   # context == &"" でプロンプト消灯
func evaluate(enemy: EnemyBase) -> StringName         # &"back"|&"above"|&"below"|&"corner"|&""
func execute(enemy: EnemyBase, context: StringName) -> void    # 両者を Assassinate 状態にロック
static func resolve(player_state: StringName, to_enemy_local: Vector3,
        enemy_alert: Enums.AlertState, seen_by_target: bool, cfg: Resource) -> StringName  # pure, §GDD 3.1

# ── src/enemies/enemy_perception.gd  (Node, enemy_base.tscn 直下 "Perception")
class_name EnemyPerception
signal stimulus(stim: PerceptionStimulus)
func tick(delta: float) -> void                       # Brain が 10 Hz/LOD で呼ぶ（自走しない）
func on_noise(event: NoiseEvent) -> void              # EventBus.noise_emitted に接続
func meter() -> float                                 # 発見メーター現在値（閾値は §2.3: 1.0/2.0/3.0）
static func vision_gain(v: float, dist: float, view_dist: float,
        central: bool, base_gain: float) -> float     # pure, §2.3 の式そのもの

# ── src/enemies/perception_stimulus.gd (RefCounted)
class_name PerceptionStimulus
var kind: Enums.StimulusKind
var priority: int          # §10.4 の優先度 P1..P5
var position: Vector3
var confidence: float      # 0..1（VISUAL はメーター比、NOISE/ANOMALY は種別固定値）
var anomaly: Anomaly       # kind == ANOMALY のときのみ非 null

# ── src/enemies/enemy_brain.gd  (Node, enemy_base.tscn 直下 "Brain")
class_name EnemyBrain
func alert_state() -> Enums.AlertState
func submit_stimulus(stim: PerceptionStimulus) -> void    # フレーム内バッファへ積む（§10.4）
func force_state(state: Enums.AlertState, reason: StringName) -> void  # ミッション演出用（M8 初期厳戒等）
func set_incapacitated(kind: StringName) -> void      # &"sleep"|&"knockout"|&"restrained"|&"dead"
                                                      # → Brain/Perception 停止。FSM の状態ではない（§10.4 注記）

# ── src/autoload/mission_director.gd
class_name MissionDirector
func start_mission(def: MissionDefinition) -> void
func complete_objective(id: StringName) -> void       # mission_event("objective_completed") を発火
func fail_mission(reason: StringName) -> void         # M9 殺害等。mission_event("mission_failed")
func current_objective() -> ObjectiveData
func stats() -> MissionStats                          # RefCounted: detections/nontarget_kills/civilian_kills/
                                                      #   bodies_found/one_strike/knockouts/elapsed_sec
func build_result() -> MissionResult                  # {score:int, rank:StringName, flags:Dictionary} §5 の形
static func compute_score(stats: MissionStats, cfg: ScoringConfig,
        def: MissionDefinition) -> MissionResult      # pure（M9/M10 特例も cfg 経由でここで解決）

# ── src/autoload/save_manager.gd
class_name SaveManager
func load_save() -> void                              # 破損時は初期化（NFR-06）+ migrate()
func commit() -> void                                 # 一時ファイル + rename
func campaign() -> Dictionary                         # §5 スキーマの campaign 節（参照でなくコピー禁止: 直接編集する）
func settings() -> Dictionary
func record_mission_result(mission_id: StringName, result: MissionResult, first_clear: bool) -> void
func write_checkpoint(snapshot: Dictionary) -> void
func clear_checkpoint() -> void
static func migrate(data: Dictionary) -> Dictionary   # pure: version フィールドを見て最新へ

# ── src/autoload/audio_director.gd
class_name AudioDirector
func set_alert_tier(tier: int) -> void                # 0 静寂 / 1 不穏 / 2 戦闘。全敵の最大 AlertState から
                                                      #   SUSPICIOUS→0, SEARCHING→1, COMBAT→2 で写像
func play_bgm_set(set_id: StringName) -> void         # &"normal"|&"festival"|&"final"
func play_stinger(id: StringName) -> void             # 必殺の無音→一拍 等
func set_ambience(id: StringName) -> void

# ── src/tools/tool_base.gd  (Node3D, ToolDefinition.effect_scene のルート基底)
class_name ToolBase
func definition() -> ToolDefinition
func use(user: Node3D, aim: Dictionary) -> bool       # aim: {origin: Vector3, dir: Vector3, target: Node3D|null}
                                                      # false = 不成立（残数を消費しない）
# 派生クラスは _apply_effect(hit: Dictionary) -> void を実装（投射着弾 or 即時使用時に呼ばれる）
```

### 10.2 シーンツリー構造

ノード名・型・順序は下記に固定（`get_node` パスが契約になるため）。

```
player.tscn
Player (CharacterBody3D)                 layer=2 player_body / mask=1 world
├─ CollisionShape3D                      # カプセル。Crouch/Crawl/Swim で shape 差し替え
├─ Visual (Node3D)
│   └─ Model (Node3D)                    # GLB + AnimationTree
├─ StateMachine (PlayerStateMachine)
├─ Visibility (PlayerVisibility)         # 遮蔽レイは PhysicsDirectSpaceState3D 直接クエリ（ノード不使用）
├─ AssassinationResolver
├─ Interactor (Area3D)                   layer=0 / mask=7|8|9|12|13|15
├─ NoiseEmitter (Node)                   # 足音・着地を EventBus.noise_emitted へ
├─ ToolRig (Node3D)
│   └─ AimArc (Node3D)                   # 投射軌道表示
├─ CameraRig (Node3D)
│   └─ SpringArm3D ─ Camera3D
└─ DetectPoints (Node3D)                 # group "player_detect_points"
    ├─ Head / Chest / Hips (Marker3D)    # 敵視覚レイの終点 3 点（§03 4.2）

enemy_base.tscn
EnemyBase (CharacterBody3D)              layer=3 enemy_body / mask=1
├─ CollisionShape3D
├─ Visual (Node3D) ─ Model
├─ Brain (EnemyBrain)
├─ Perception (EnemyPerception)
│   └─ EyePoint (Marker3D)               # 視覚レイの始点
├─ NavigationAgent3D
├─ Combat (Node)                         # 攻撃・被弾・HP（§6 の値は PerceptionConfig と別の EnemyStats Resource）
├─ AssassinateTarget (Area3D)            layer=11 / mask=0   # 必殺プロンプト検出用
├─ MeterAnchor (Marker3D)                # 頭上メーター HUD の投影点
└─ Carryable (Node)                      # 死亡/拘束後に有効化。有効時 EnemyBase の layer を 9 corpse へ変更

レベルテンプレート (levels/_template.tscn)
Level (Node3D)
├─ Geometry (Node3D)                     # 静的メッシュ+StaticBody3D layer=1（視線遮蔽は +5、音遮蔽は +6）
├─ NavigationRegion3D
├─ Lights (Node3D)                       # LightSource 群, group "lights"
├─ Enemies (Node3D)                      # group "enemies"
├─ Civilians (Node3D)                    # group "civilians"（Phase 2）
├─ Markers (Node3D)                      # HideSpot/ClimbEdge/BeamPath/CrawlEntrance/SearchPoint/
│                                        #   RoutineStop/PatrolPath/AnomalyMarker 群
├─ Objectives (Node3D)                   # MissionObjective/CheckpointArea (Area3D layer=15)
├─ PlayerSpawn (Marker3D)
└─ WeatherController (Node)              # MissionDefinition.weather を適用（Phase 2）
```

### 10.3 コリジョン / 物理レイヤー表

project.godot の layer_names に下記を登録すること（Issue #1）。

| # | 名称 | 載せるもの |
|---|---|---|
| 1 | world | 静的地形・建築のコリジョン |
| 2 | player_body | Player 本体 |
| 3 | enemy_body | 敵本体 |
| 4 | civilian_body | 民間人本体 |
| 5 | vision_blocker | 視線を遮る面（壁は 1+5 両方、閉じた障子・襖は 5 のみ = 体は破れるが視線は通らない）。**茂み等 SoftCover は含めない**（可視度補正 ×0.3 で処理、§GDD 2.1） |
| 6 | sound_blocker | 音遮蔽レイ用の壁面。戸・襖は開閉で当該 shape を on/off |
| 7 | interactable | 灯篭・戸・巻き上げ機などのインタラクト Area |
| 8 | hidespot | HideSpot の進入 Area |
| 9 | corpse | 死体・拘束体（Carryable 有効化後） |
| 10 | projectile | 忍具投射物 |
| 11 | assassinate_target | 敵の必殺プロンプト検出 Area |
| 12 | climb_marker | ClimbEdge / BeamPath / CrawlEntrance の検出 Area |
| 13 | water | 水域 Area |
| 14 | （予約: detection 拡張） | |
| 15 | mission_trigger | CheckpointArea / MissionObjective / 雑踏 HideSpot の悲鳴判定 |
| 16–20 | 予約 | 使用する場合は本表を先に更新 |

**レイキャスト / Area マスク一覧（これ以外のマスク値を実装で発明しない）**

| 用途 | 始点 → 終点 | mask |
|---|---|---|
| 敵の視覚遮蔽 | EyePoint → DetectPoints 3 点 | 1\|5（ヒットなし = 視認成立） |
| 光量の遮蔽（V 計算） | LightSource → Chest（上位 3 光源は 3 点） | 1\|5 |
| 音の遮蔽（半減判定） | NoiseEvent.position → 敵 EyePoint | 6（ヒット 1 枚ごとに実効半径 ×0.5、§1） |
| 忍具投射物の飛翔 | 発射軌道 | 1\|3\|4\|7 |
| プレイヤー Interactor | Area 重なり | 7\|8\|9\|12\|13\|15 |
| 必殺プロンプト検出 | プレイヤー前方の短距離 Area | 11（成立判定本体は AssassinationResolver.resolve） |
| 敵の捜索時の隠れ場所確認 | Brain → HideSpot | 8 |

### 10.4 敵 FSM 遷移擬似コード（刺激優先順位を含む正本）

§3 の遷移表・§GDD 4.1 の図を実装レベルに具体化したもの。**同一フレームに複数の刺激が来た場合、最高優先度の 1 件のみを処理し、残りは破棄する**（次フレームで再発生する刺激は再評価される）。同率は敵からの距離が近い方を採用。

**優先度定義（高 → 低）**

| P | 刺激 | 発生源 |
|---|---|---|
| P5 | 戦闘中の視認継続・被攻撃（DAMAGE） | Perception / Combat |
| P4 | 視認メーター combat 閾値（3.0）到達 | VISUAL |
| P3 | severity 3 の異常視認（CORPSE / RESTRAINED）、SCREAM / COMBAT 音 | ANOMALY / NOISE |
| P2 | 視認メーター search 閾値（2.0）到達、severity 2 の異常視認 | VISUAL / ANOMALY |
| P1 | 通常音（FOOTSTEP / LANDING / TOOL / DOOR / BELL）、severity 1 の異常（LIGHT_OUT / FOOTPRINT / DOOR_OPEN / PROP_FALLEN / TRAP_DISARMED）、視認メーター suspicious 閾値（1.0）到達 | NOISE / ANOMALY / VISUAL |

```
# EnemyBrain._physics_process(delta) — 毎フレーム。Perception.tick は 10 Hz/LOD 側で駆動
stim := pop_highest(stim_buffer); stim_buffer.clear()

if incapacitated: return          # sleep/knockout/restrained/dead は FSM の外（状態を保持したまま停止）

match state:
  UNAWARE:
    run_routine()                                   # PatrolPath / RoutineStop
    if stim.P >= P4: to(COMBAT, stim)               # 至近の確定視認は不審を飛ばす
    elif stim.P == P3: to(SEARCHING, stim); raise_area_alert_if(severity == 3)
    elif stim.P >= P1: to(SUSPICIOUS, stim)

  SUSPICIOUS:                                       # 凝視 → 歩いて確認（Investigate サブ状態）
    investigate(stim_memory.position)               # 到着後 3 秒調査
    if stim.P >= P4: to(COMBAT, stim)
    elif stim.P >= P2: to(SEARCHING, stim)
    elif stim.P == P1: stim_memory = stim           # 調査先を更新（状態は維持）
    elif investigate_done and nothing_found:
      if anomaly_was(LIGHT_OUT): enter_sub(RELIGHT) # 約 60 秒後に再点灯（§GDD 2.2）
      to(RETURN)

  SEARCHING:                                        # 走って SearchPoint を確信度順に巡回・一部の HideSpot を覗く
    propagate_alert(radius = 12 m)                  # FR-AI-07: 近傍の敵を SUSPICIOUS 以上へ
    if stim.P >= P4: to(COMBAT, stim)
    elif stim.P >= P1: search_focus = stim.position; search_timer = 0
    elif search_timer > 60 s: to(RETURN)            # チューニング値 perception.tres

  COMBAT:
    attack_or_chase(); call_for_help()
    if lost_sight_for(3 s): to(SEARCHING, last_known_position)
    # COMBAT 突入は 1 回だけ MissionDirector.stats().detections += 1 と area_alert +1（戦闘発生, §GDD 4.1）

  RETURN:
    navigate_back_to_routine()
    vigilance_mult = 1.5 while return_vigilance_timer < 120 s   # §2.3 警戒残置
    if stim.P >= P4: to(COMBAT, stim)
    elif stim.P >= P2: to(SEARCHING, stim)
    elif stim.P == P1: to(SUSPICIOUS, stim)
    elif arrived: to(UNAWARE)

to(next, stim): EventBus.alert_changed.emit(self, state, next); state = next; stim_memory = stim
```

**補足規約**

- VISUAL 刺激の P 値は Perception 側で決める: メーターが閾値 1.0 / 2.0 / 3.0 を跨いだフレームにのみ P1 / P2 / P4 を発行（跨がない蓄積中は刺激なし）
- ANOMALY は同一 Anomaly につき同一個体からは 1 回だけ発行（`anomaly.seen_by` セットで管理）。CORPSE 発見時の `bodies_found` 加算・エリア警戒 +1 は Brain ではなく MissionDirector が `anomaly_spotted` を購読して行う
- 昏倒・拘束・死亡は FSM 状態ではなく `set_incapacitated()`（§10.1）。覚醒時は SEARCHING から復帰（自分が襲われた事実 = P3 相当）
- 宗玄（M10）は本 FSM を継承し UNAWARE/RETURN を持たない（常時 SEARCHING ↔ COMBAT + 独自の離脱行動）。詳細は Issue #74

### 10.5 整合確認メモ（2026-07-03 実施）

- `alert_changed` の int = AlertState（§1 ↔ §10.0）: 一致
- 閾値 1.0/2.0/3.0（§2.3）と P1/P2/P4 の対応（§10.4）: 一致
- Anomaly severity 1/2/3 → 不審/捜索/捜索+エリア警戒（§1）と UNAWARE 分岐（§10.4）: 一致
- SCREAM/COMBAT = 即捜索（§1 注記）= P3（§10.4）: 一致
- 死体発見のエリア警戒 +1（§GDD 3.3）の責務を MissionDirector に一本化（§10.4 補足）: §1 の `anomaly_spotted` 購読で成立
- §6 敵ステータス（HP/攻撃力）は PerceptionConfig と別 Resource（EnemyStats）である旨を §10.2 に明記: §2.3 と矛盾なし
