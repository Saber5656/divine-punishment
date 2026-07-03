# Issue #5: EventBus / GameState / SaveManager の autoload 骨格

- Milestone: M0 / ラベル: area:infra, type:feature
- 依存: #1, #2
- ゲート: G1

## 目的

疎結合アーキテクチャの中核（共通 enum・イベントの型・autoload 群）を先に固定する。以降の全 Issue はここで定義されたシグナルと enum に接続するため、**docs/08 §1 / §10.0 からの転記の正確さがすべて**。

## 読むべき仕様（読む順）

1. docs/08-content-specs.md §1 — EventBus シグナル契約・NoiseEvent / Anomaly
2. docs/08-content-specs.md §10.0–§10.1 — enum・SaveManager / MissionDirector / AudioDirector の API
3. docs/08-content-specs.md §5 — セーブスキーマ（migrate の対象）
4. docs/03-technical-design.md §3.1 — 各 autoload の責務

## 変更対象パス

| パス | 種別 | 内容 |
|---|---|---|
| `src/core/enums.gd` | 新規 | `class_name Enums`。AlertState / Stance / StimulusKind（§10.0 そのまま）+ NoiseKind / AnomalyKind（§1） |
| `src/core/noise_event.gd` | 新規 | `class_name NoiseEvent extends RefCounted`（§1 のフィールド） |
| `src/core/anomaly.gd` | 新規 | `class_name Anomaly extends RefCounted`（§1 のフィールド + `seen_by: Dictionary` セット） |
| `src/autoload/event_bus.gd` | 新規 | §1 の全シグナルを**宣言のみ**（発火ロジックは各機能 Issue） |
| `src/autoload/game_state.gd` | 新規 | 現在ミッション id / エリア警戒 level / チェックポイント参照の骨格 |
| `src/autoload/mission_director.gd` | 新規 | §10.1 の全メソッドを型どおりに宣言。中身は `push_warning("not implemented")` + 最低限の stats カウンタ保持のみ |
| `src/autoload/audio_director.gd` | 新規 | 同上（§10.1 の 4 メソッド） |
| `src/autoload/save_manager.gd` | 新規 | `load_save / commit / campaign / settings / migrate` を実装（本 Issue で唯一「動く」ところ） |
| `tests/unit/test_save_manager.gd` | 新規 | migrate・往復・破損時初期化 |
| `tests/unit/test_enums.gd` | 新規 | enum 値の固定（AlertState.COMBAT == 3 等 — 順序変更の事故防止） |

## 実装手順

1. `enums.gd` を §10.0 + §1 から転記。**値の明示**（`UNAWARE = 0` 形式）で書く
2. NoiseEvent / Anomaly を §1 の表どおりに。コンストラクタは `static func create(...)` 形式で必須フィールドを強制
3. `event_bus.gd`: §1 のシグナルを全件、引数名・型込みで宣言。予約 `mission_event` 名は定数 `const EV_OBJECTIVE_COMPLETED := &"objective_completed"` … として同ファイルに列挙
4. autoload 登録順（依存順に）: `Tuning` → `EventBus` → `GameState` → `SaveManager` → `MissionDirector` → `AudioDirector`
5. `save_manager.gd`:
   - 保存先 `user://save.json`。`commit()` は `user://save.json.tmp` に書いて `DirAccess.rename_absolute`
   - `load_save()`: ファイルなし → §5 スキーマの初期値を生成 / JSON parse 失敗 → バックアップに退避して初期化（`push_warning`）
   - `static migrate(data)`: `version` が現行（2）未満なら段階変換。現時点は「version 1（存在しない過去形式）→ 2」のスタブと、未知 version → 初期化
6. テスト: enum 固定値 / migrate（v1 相当 dict → v2）/ 保存 → 読込 → 一致 / 壊れ JSON → 初期化される

## 検証手順

```bash
./scripts/run_tests.sh   # test_save_manager, test_enums 全 pass
godot --headless --quit --path .   # autoload 6 件の読み込みエラーなし
```

- 手動確認: エディタ実行 → 終了 → `user://save.json` が生成され §5 のスキーマ形であること（パスは Project → Open User Data Folder）

## 完了条件（DoD）

- [ ] Issue #5 受け入れ条件 全チェック
- [ ] シグナル・enum・スキーマが docs/08 §1 / §10.0 / §5 と 1:1（過不足なし）
- [ ] autoload 登録順が上記のとおり
- [ ] CONTRIBUTING §4 共通 DoD

## レビュー観点

- シグナル引数の型抜け（`enemy: Node` を無型にしていないか）
- enum の暗黙値（明示値なしだと将来の挿入で全保存データが壊れる）
- `commit()` の rename が Windows で失敗するパス（既存ファイルがある場合の上書き挙動）を考慮しているか

## 実装しないこと（スコープ外）

- MissionDirector の採点実装（#35）、AudioDirector の実音再生（#25/#46）、checkpoint スナップショットの中身（#31）、ナラティブ変数（#51 — campaign 節に器だけ用意する）
