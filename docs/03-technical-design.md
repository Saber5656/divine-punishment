# Divine Punishment — 技術設計書

作成日: 2026-07-03
ステータス: Draft v3
前提: **Godot 4.3 stable に固定**（GDScript 主体）。全実装エージェント・CI・エクスポートテンプレートは同一マイナーバージョンを使用すること。マイナーバージョンを上げる場合（例: 4.3 → 4.4）は必ず Issue 化し、動作検証込みでプロジェクト全体を一括移行する。個別 PR での勝手なバージョン変更は禁止。

> **注**: 本書はアーキテクチャ方針を定める。シグナルシグネチャ・Resource スキーマ・数値表・セーブスキーマの**正本は [08-content-specs.md](08-content-specs.md)**（実装コントラクト）であり、両者が食い違う場合は 08 に従い本書を修正する。キャンペーン固有システム（カットシーン / 天候 / 非殺傷 / 敵忍 / 決闘ボス）の仕様は 07・08 を参照。

## 1. 技術方針

| 項目 | 決定 | 理由 |
|---|---|---|
| エンジン | Godot 4.3 stable（固定・冒頭注記参照） | OSS・権利面が軽い・3D ステルスに十分 |
| 言語 | GDScript（型付け必須 `--strict` 相当の運用） | イテレーション速度優先。ホットパスのみ C++/GDExtension を将来検討 |
| レンダラ | Forward+ | 動的ライト多数（灯篭・篝火）を扱うため |
| 物理 | Godot 内蔵 GodotPhysics（4.3 固定のため。Jolt は 4.4 系への一括移行 Issue で検討） | |
| テスト | GUT（Godot Unit Test） | 知覚計算・評価集計の回帰防止 |
| CI | GitHub Actions + headless Godot | テスト・3 OS エクスポート |
| データ | チューニング値は `.tres`（Resource）+ 一部 JSON | エディタ編集とドキュメント性の両立 |

## 2. プロジェクト構成

```
project.godot
addons/gut/
src/
  autoload/        # GameState, EventBus, SaveManager, AudioDirector, MissionDirector
  player/          # player.tscn, 状態機械, 移動, インタラクション
  enemies/         # enemy_base.tscn, 知覚, FSM, ルーチン, 敵タイプ派生
  stealth/         # 可視度計算, 光源, 音イベント, 異常オブジェクト
  interactables/   # 灯篭, 戸, 隠れ場所, 床下口, 死体
  tools/           # 忍具（データ駆動）
  ui/              # HUD, タイトル, ミッション選択, ポーズ, リザルト
  missions/        # ミッション定義, 目標, 評価集計
  levels/          # ステージシーン (tutorial/, mansion/)
data/
  tuning/          # perception.tres, movement.tres, scoring.tres ...
  profiles/        # player_profile_default.tres（将来のキャラ切替用）
  tools/           # tool_stone.tres, tool_blowgun.tres, tool_smoke.tres
tests/
  unit/            # 知覚数式, 評価集計, 状態遷移
  integration/     # シーン読み込みスモーク
docs/
```

## 3. コアアーキテクチャ

### 3.1 Autoload（シングルトン）

| Autoload | 責務 |
|---|---|
| `EventBus` | 型付きシグナルのハブ。音イベント・異常イベント・警戒変化・ミッションイベント |
| `Tuning` | `data/tuning/` の Resource をロードし、デバッグビルドで F5 リロードを提供 |
| `GameState` | 現在ミッション・エリア警戒レベル・チェックポイント |
| `MissionDirector` | 目標管理・評価カウンタ（発見回数 / 死体発見 / 殺害数 / 時間）・リザルト生成 |
| `AudioDirector` | 警戒段階に応じた BGM レイヤリング、SE バス管理 |
| `SaveManager` | クリア状況・ベストランク・設定の永続化（`user://save.json`） |

原則: ゲームプレイオブジェクト同士は直接参照せず、`EventBus` シグナル + グループ（`lights`, `enemies`, `hideables`）で疎結合にする。

### 3.2 音・異常イベント（ステルスの神経系）

```gdscript
# EventBus
signal noise_emitted(event: NoiseEvent)      # {position, radius, kind, source}
signal anomaly_spotted(anomaly: Anomaly)     # 死体/消灯/開いた戸 …
signal alert_changed(enemy: Enemy, from: AlertState, to: AlertState)
```

- `NoiseEvent` は物理を使わず、`enemies` グループへ距離 + 壁遮蔽（1 レイキャスト）で配送
- `Anomaly` はシーン内ノード（`AnomalyMarker`）。敵の視覚更新時に「視認できる異常」を拾う

## 4. ステルスサブシステム

### 4.1 可視度計算（PlayerVisibility）

- 各 `LightSource`（自作ノード、`OmniLight3D`/`SpotLight3D` をラップ）が `lights` グループに登録
- プレイヤー側で 0.1 秒間隔（10 Hz）で更新:
  1. 距離カリング（影響半径外の光源を除外）
  2. 光源ごとに距離減衰 + 遮蔽レイキャスト（プレイヤー胸 1 点、上位 3 光源のみ 3 点）
  3. `V = clamp(Σ光量 × スタンス × 移動 × SoftCover)`
- **レンダリングのライトとゲームプレイの光量を分離**する（見た目調整でステルスが壊れない）。`LightSource` がレンダーライトとゲームプレイ半径の両方を持ち、エディタで同期表示

### 4.2 敵知覚（Perception, 敵ごとのコンポーネント）

- 更新は 10 Hz + LOD（プレイヤーから 30 m 超は 2 Hz）
- 視覚: 視野角・距離チェック → 3 点レイキャスト → 蓄積式発見メーター
  `meter += gain(V, distance, 中心視) × Δt`、減衰は非視認時
- 聴覚: `EventBus.noise_emitted` 購読
- 出力は `PerceptionStimulus`（種別・確信度・位置）として FSM へ渡す。**知覚と意思決定を分離**し、知覚数式を純粋関数としてユニットテスト可能にする

### 4.3 敵 FSM

`EnemyBrain`（FSM）: `Unaware / Suspicious / Searching / Combat / Return` + サブ状態（Investigate, CallForHelp, Relight）。

- ルーチン: `Path3D` ベースの巡回 + `RoutineStop`（立哨・休憩・書見などの滞在ポイント、時刻タグ付き）
- ナビゲーション: `NavigationRegion3D` + `NavigationAgent3D`。梁・屋根は敵の進入不可領域（プレイヤー専用経路）
- 捜索: 最終確認地点周辺の `SearchPoint`（レベル設計者が配置）を確信度順に巡回
- 標的 NPC は同じ FSM に専用ルーチン（時刻イベントで滞在ポイントを移動）

### 4.4 プレイヤー状態機械

`Ground / Crouch / Sprint / WallCling / Climb / Beam / Crawlspace / Swim / Hidden / Carry / Combat / Assassinate / Dead`。
状態ごとに移動パラメータ・発音倍率・可視度補正・使用可能アクションをデータ（`movement.tres`）から引く。

### 4.5 必殺判定

`AssassinationResolver`（プレイヤー側）: 対象敵に対し §GDD 3.1 の条件を判定し、成立時に文脈タグ（`back/above/below/corner`）を返す。実行時は両者を `Assassinate` 状態にロックし、短いアニメ + カメラ（`Camera3D` ブレンド）を再生。演出中も他の敵の知覚は生きている（頭上必殺を目撃されるリスクを残す）。

## 5. レベル制作パイプライン

1. **グレーボックス**: CSG / 簡易メッシュ + 全ゲームプレイマーカー（光源・巡回・SearchPoint・隠れ場所・床下口・登攀縁）
2. プレイテスト・チューニング（この段階で経路 3 系統と評価バランスを確定）
3. **アートパス**: モジュラー和風アセット（畳・襖・柱・塀・屋根瓦）で置換。コリジョンとマーカーは維持
4. ライティングパス: レンダーライトを調整し、`LightSource` ゲームプレイ半径と目視で整合確認

レベル用カスタムノード: `LightSource`, `HideSpot`, `CrawlEntrance`, `ClimbEdge`, `BeamPath`, `SearchPoint`, `RoutineStop`, `PatrolPath`, `CheckpointArea`, `MissionObjective`。すべてエディタギズモ表示付き（レベルデザインの生産性）。

## 6. データ駆動設計

### 6.1 チューニング（NFR-04）

`data/tuning/*.tres`（カスタム Resource）: 知覚（視野角・距離・蓄積速度）、移動（速度・音半径）、材質音倍率、評価配点、忍具パラメータ。実行中リロード（デバッグビルドで F5）対応。

### 6.2 プレイヤープロファイル（NFR-07・将来のキャラ切替）

`PlayerProfile` Resource: 移動速度セット・発音倍率・忍具スロット数・可能アクション集合。VS では default 1 種のみだが、Player はプロファイル注入で動く構造にする。

### 6.3 忍具

`ToolDefinition` Resource（名称・所持数・投射 / 使用挙動シーン参照・効果パラメータ）。忍具追加はリソース + 効果シーンの追加のみで済む構造。

## 7. UI / セーブ / 設定

- HUD: 可視度リング・忍具スロット・敵メーター（敵頭上 3D → 2D 投影）。`CanvasLayer` + テーマ統一
- 画面フロー: `Title → MissionSelect → (Loading) → Mission → Result → MissionSelect`。`SceneDirector`（autoload に含めず `Main` シーンで管理）
- セーブ: `user://save.json`（クリア状況・ベストランク・設定）。書き込みは一時ファイル + rename で破損防止
- 入力: `InputMap` ベース、パッド / KBM 両対応。リマップ UI は設定画面（S 優先度）

## 8. パフォーマンス設計（NFR-02）

- 知覚 10 Hz + 距離 LOD、光量計算 10 Hz、レイキャストは 1 更新あたり敵 1 体 ≤ 4 本
- 敵 12 体 + 光源 20 個で知覚系合計 ≤ 1 ms/frame を目標（プロファイラで計測 Issue 化）
- 静的シャドウのライトはベイク（`LightmapGI`）、ゲームプレイ光源のみ動的シャドウ

## 9. テスト・CI

| 種別 | 対象 | ツール |
|---|---|---|
| Unit | 可視度数式・発見メーター蓄積・音減衰・評価集計・FSM 遷移表 | GUT |
| Integration | 各シーンの読み込みスモーク・セーブ往復 | GUT (headless) |
| Playtest 支援 | デバッグオーバーレイ（視野コーン・光量半径・音波紋の可視化トグル） | 自作 |
| CI | push / PR で GUT 実行、main で Win/mac/Linux エクスポート artifact | GitHub Actions |

## 10. リスクと対応

| リスク | 対応 |
|---|---|
| 3D アニメ制作コスト（必殺・剣戟） | 汎用ヒューマノイドリグ + 購入 / CC0 モーション + Godot アニメリターゲット。必殺演出は文脈 4 種に限定 |
| 知覚の「理不尽感」調整が長期化 | デバッグ可視化を最優先で実装（M2 内）。チューニングをデータ化し反復を高速化 |
| Godot の梁 / 登攀移動の実装難度 | 汎用クライミングではなくマーカー（`ClimbEdge`/`BeamPath`）限定の割り切り |
| アートの品質目標が VS を膨張させる | アートパスは「武家屋敷」1 面のみ。チュートリアルはグレーボックス + 簡易テクスチャで可 |
