# Issue #38 — 山道の関所チュートリアル

## 目的・範囲

`docs/04-level-design.md` §2 の5区画を通じ、忍び足・潜伏・誘導・消灯・必殺・死体隠しを実際に使って密書を回収し、二つの脱出経路から結果画面へ到達できるようにする。既存の全Issue対応のうち本機能だけを担当する。#36 の Main / SceneDirector、#30 の再潜伏、production Player / Enemy / LightSource / HideSpot / ToolRig / ClimbEdge を使う。アート完成や外部プレイテストの代替とはしない。

source 所有: `src/levels/tutorial/`、`data/missions/tutorial.tres`、tutorialのfocused/integration tests、QA記録、本指示書。共有 `src/ui/scene_director.gd` と `data/text/ja.csv` は #36 担当のコミット取り込み後に最小の登録差分を加える。他のsourceの機能不足は既存APIを調べてから必要な範囲を親と共有する。

branch `codex/issue-38-tutorial-20260907`、worktree同名。開始base7332cf24b3ac34e8d8e110935dc8550c8be509ec、開始clean。親がVault登録済。次のsource実装前に本設計を確認・具体化しcommitする。今回Saihai起動は人間の明示免除、親が実装→検証→PR→CI→mergeを管理。通常追加review不要。

## 実装契約

- 独立 Node3D level scene、直下に production `Player` を一体置く。Main に永続 SceneDirector、missionはその兄弟という #36 契約を維持する。
- MissionDefinition id `m01`、日本語タイトルはtext key経由。段階のObjectiveDataを順序付きで定義し、最後は密書取得→escape。SceneDirector.start_mission(definition) から開始して final objective completion event で結果へ遷移する。
- 4敵（立哨2、巡回2）。コースは5つの認識しやすい区画、月明かりと木陰、崖の岩、砂利、番小屋、関所門をprimitive geometryと簡易材質で描く。1区画の大きさは概ね18×22m、直列全長約110mを出発点に、物理移動と視認性で調整する。床上面は立位capsule中心より0.9m下、壁・屋根・rampは実collisionと一致させる。
- 学習の進行判定は production state / EventBus / 所有ノードの実結果を読む。キーを押した事実だけ、Areaに入っただけで複合学習完了にしない。別区画の光/敵/音イベントを誤集計しない。
- 次区画の仕切りは「まだ教えていない行動を無視して走り抜ける」ことを防ぐ実collision付き通行止め。達成すると道を開ける。未達の要件は常に一文で読める。必須の敵を早期に倒す等で達成不能になったら、進行不能のまま放置せず理由を示してcheckpoint retryへ戻せる。
- 体験中の案内は短い日本語一文＋必要な現在の入力binding表示。進捗はHUDに一つだけ表示、巨大なデバッグ数値を常設しない。文字列は既存GameText/CSVに外出しし、フォントはGameUiと共通化する。入力再割り当て後に固定の古いキーを案内しない。
- checkpoint再開では完了済み学習と必要な世界状態が整合する。#31 snapshotはJSON互換値、#40と共通APIが必要なら担当と相談し二重定義しない。

## 区画と受入観測

| 区画 | 必須行動・観測 | 物理配置 |
|---|---|---|
| 1 山道 | Crouchで一定距離を進み、月明かりと木陰でproduction visibilityが変わる。HUDに実Vが反映される | 背を向けた立哨、遮光する樹冠/岩、明暗を比較できる安全位置 |
| 2 崖沿い | HideSpotでHiddenに入り巡回をやり過ごして退出し、壁沿いの覗き見でcamera peek offsetが実際に変わる | 巡回経路、茂み、壁張り付きとpeekが成立する岩角。潜伏直後の近距離視認を避けられる入口 |
| 3 番小屋前 | production pebble impact noiseによって担当立哨がInvestigate等の反応に移り、砂利の音コストを実際の移動で示す | 石の投げ先が見える砂利と退避位置。ツール在庫とtrajectoryを正常利用 |
| 4 番小屋 | 所有する灯籠2つを消し、担当巡回敵へ背後必殺を実行し、生成されたbodyを持ってHideSpotに収納する | 隠し場所に運ぶ通路はproduction capsuleで通行可能。敵を隠した後に密書を取得できる |
| 5 関所門 | 地上は誘導＋消灯を使う短い経路、屋根はproduction climbを使う別経路からescape Areaへ入る | 両routeとも通常入力で通れて同じ結果へ到達。区画3の担当敵などを再利用する場合は4敵総数・前段達成と両立させる |

区画5の敵再利用や区画3/4の配置は実装担当が上表の学習・4敵・二経路を同時に満たす形へ設計を具体化する。敵を強制teleportしてプレイヤーの背後へ出現させるような不自然な解決を使わない。

## 検証

focused: 無関係イベントでは進行しない、手順を飛ばせない、必要行動が実結果から集計される、premature kill時に再開可能、4敵と5区画・2route、checkpoint再開、最後まで結果へ到達する。

物理統合: production capsuleで床・壁・通行止め・登攀・body運搬を確認する。テスト用にフラグを直接trueにするだけの成功は学習成立の証拠にしない。必要なunit fixtureと実入力runtimeの役割を区別する。

可視QA: 通常Input経路で地上と屋根の両routeを通して起動→5学習→密書→escape→result。表示・実V・敵反応をスクリーンショットとログで確認。time_scale1、瞬間移動でのクリアを実プレイとして数えない。所要時間は実測し、5〜10分目安から外れる理由と調整を記録する。

統合変更一式でrepository full validationを一回。非影響結果は再利用し、同一原因の失敗のみretry数を数える。artifact/validation/publication/mergeを混同せず、未実施の実利用は明記する。
