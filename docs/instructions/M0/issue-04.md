# Issue #4: チューニング Resource 基盤（data/tuning + デバッグリロード）

- Milestone: M0 / ラベル: area:infra, type:feature
- 依存: #1, #2
- ゲート: G1

## 目的

「数値はすべてデータで持ち、実行中に差し替えられる」という NFR-04 の基盤を作る。以降の全ゲームプレイ Issue は、ここで作る Resource クラスにフィールドを足していく。

## 読むべき仕様（読む順）

1. docs/03-technical-design.md §6.1 — データ駆動方針
2. docs/08-content-specs.md §2.3, §2.7, §2.8 — PerceptionConfig / WeatherConfig / ScoringConfig のフィールド定義
3. docs/02-game-design.md §1.1, §7 — movement / scoring の初期値

## 変更対象パス

| パス | 種別 | 内容 |
|---|---|---|
| `src/core/tuning/perception_config.gd` | 新規 | `class_name PerceptionConfig extends Resource`。§2.3 の全フィールドを `@export` で（敵タイプ別の値は本 Resource を 4 つ作って表現: 足軽 / 弓見張り / 敵忍 / 宗玄） |
| `src/core/tuning/movement_config.gd` | 新規 | GDD §1.1 のスタンス別表 + 材質音倍率 Dictionary |
| `src/core/tuning/scoring_config.gd` | 新規 | §2.8 の配点・特例値・epilogue_a_condition |
| `src/core/tuning/weather_config.gd` | 新規 | §2.7 の表 |
| `src/autoload/tuning.gd` | 新規 | autoload `Tuning`（下記 API） |
| `data/tuning/perception_ashigaru.tres` ほか | 新規 | 初期値入り .tres（perception ×4, movement, scoring, weather） |
| `tests/unit/test_tuning.gd` | 新規 | ロード・初期値・リロードのテスト |
| `docs/03-technical-design.md` §3.1 | 変更 | autoload 表に `Tuning` の行を追加（仕様同期。CONTRIBUTING §4） |

## Tuning autoload の API（この形で実装する）

```gdscript
class_name TuningService  # autoload 名は "Tuning"
func perception(kind: StringName) -> PerceptionConfig   # &"ashigaru"|&"archer"|&"shinobi"|&"sogen"
func movement() -> MovementConfig
func scoring() -> ScoringConfig
func weather() -> WeatherConfig
func reload() -> void            # 全 .tres を CACHE_MODE_IGNORE で再読込し、reloaded を emit
signal reloaded()
```

## 実装手順

1. Resource クラス 4 本を作成。フィールド名は docs/08 の表の英語名をそのまま snake_case で使う（例: `fov_degrees`, `meter_gain_base`）。**表にない独自フィールドを足さない**
2. .tres を Godot エディタ上で作成し、docs/02 / 08 の初期値を全フィールドに入力する
3. `Tuning` autoload を実装し、Project Settings に登録（登録名 `Tuning`）
4. デバッグリロード: `OS.is_debug_build()` のとき `_input()` で F5 を拾い `reload()`。リリースビルドでは入力ごと無効
5. テスト: ①全 .tres がロードできる ②代表値の一致（例: ashigaru の fov_degrees == 110）③ reload() 後も値が取れる

## 検証手順

```bash
./scripts/run_tests.sh    # test_tuning 全 pass
```

- 手動確認: エディタ実行 → .tres の値を外部エディタで書き換え → F5 → `print(Tuning.perception(&"ashigaru").fov_degrees)` が新値になる（確認用の一時 print は削除してから PR）

## 完了条件（DoD）

- [ ] Issue #4 受け入れ条件 全チェック
- [ ] フィールド名が docs/08 の表と 1:1（過不足なし）
- [ ] docs/03 §3.1 の autoload 表に Tuning を追記した
- [ ] CONTRIBUTING §4 共通 DoD

## レビュー観点

- 初期値の転記ミス（§2.3 / §2.8 / GDD §1.1 と全数突き合わせ）
- `CACHE_MODE_IGNORE` を使わず reload が効いていない、の見落とし
- リリースビルドで F5 が生きていないか

## 実装しないこと（スコープ外）

- ToolDefinition / MissionDefinition / PlayerProfile（それぞれ #32 / #35 / #6 で、本 Issue のパターンを踏襲して作る）
- 数値を使う側の実装（#6 以降）
