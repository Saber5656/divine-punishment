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

## 実装前の配置具体化（2026-09-07）

座標はx=東、-z=進行、床上面y=0、player/enemy中心y=0.9。直線3区画から東の番小屋へ曲がり、関所門へ戻る鉤形とする。これにより第三区画の立哨が自然に門前も見張り、第五の敵を追加しない。敵の強制移動は行わない。

| 場所 | 座標範囲/敵 | 実結果の判定 |
|---|---|---|
| 山道 | x±8,z8..-18。立哨A(-4,-14)は奥向き | Crouchの地上移動3m、明所Vと木陰Vの差0.08以上。時間/距離は範囲内の実position差のみ加算 |
| 崖 | x±8,z-18..-38。巡回Bは(-3,-25)↔(3,-33) | 指定HideSpotのHidden中にBの実移動2m以上＋3秒潜伏後に退出、指定岩角付近でWallClingのcamera peek offsetが0.05m以上 |
| 番小屋前 | x±8,z-38..-58。立哨C(2,-59)が東の連絡路も監視 | 自分のNoiseEmitterによる砂利FOOTSTEP、選択stoneからのTOOL音impactがCから6m以内、Cが該当音へ反応し実移動0.5m以上 |
| 番小屋 | x12..24,z-50..-66。巡回D(15,-55)↔(20,-61) | 指定灯籠2つoff＋Dのmethod=assassination/context=back＋Dの実bodyをcarry後に指定HideSpot.stored_bodyとして確認。次に密書の近接interact |
| 関所門 | x0..20,z-66..-84。Cを同じ持ち場から共用 | 地上: 新しいstone音でCが移動＋門前灯籠offで地上柵を開く。屋根: 指定ClimbEdgeでCLIMB→上面到達後に屋根出口。どちらも密書取得後だけescape完了 |

第三区画の石投げ先は(1,-55)、第五区画は(6,-59)を目印とし、どちらもCの初期位置から音半径6m内。巡回/誘導には敵ごとの通行可能なNavigationRegionを設定し、navmesh未同期/空のまま「反応した」と数えない。明所は消せない月光用LightSource、木陰は実world collisionで光rayを遮る樹冠/岩。石の補充は有限stock枯渇でsoftlockさせないため、番小屋入口にインタラクト式の小石箱を置く（補充行為自体は学習達成に含めない）。

区画間の柵はcollisionを持ち、学習順序が一致した場合のみ開く。立哨Cの早期死亡、Dの戦闘撃破、Hidden達成前のB死亡など必須条件を失ったらmission_failedに具体的な日本語理由を出し、#36のRetryから再開する。任意retryは常に残す。

MissionDefinitionはm01、順序IDはtutorial_sneak/tutorial_hide/tutorial_lure/tutorial_lights/tutorial_assassinate/tutorial_body/tutorial_document/tutorial_escape。区画4を消灯→必殺→bodyの3objectiveに細分化し、必殺のみKILL_TARGET、他学習LEARN、密書COLLECT、最後ESCAPEとする。Dのgroupはtutorial_target。既存MissionDirectorのKILL_TARGET識別と実暗殺methodでone_strikeを計算するためcore変更/評価捏造は不要。必殺objective開始前にDを倒した場合はretryへ誘導する。

#36のSceneDirector.set_mission_hint(text)へ短文とInputMap現在bindingを渡す。objective text_keyはGameText参照、固定キー表示は使わない。#40が追加するactive mission/checkpoint APIに合わせ、world snapshotのキーはtutorial専用名前空間に保存してrestore_checkpoint_world(snapshot)で復元する。どのcheckpointにも必要敵・灯り・柵・学習progressの復元を含める。API合流前のstandalone検証は明示し、checkpoint対応済みとは数えない。

## 実操作検証からの配置補正（2026-09-08）

上の初期配置記録は設計履歴として保持する。以下が実装の最終値である。

- 木陰の達成は距離による光量減衰だけでは成立させない。MoonPoolからPlayerのChestへのworld rayがPineCanopyを遮蔽物として返した場合のみ暗所Vを採用し、実Crouch移動と明暗差も必要とする。
- 巡回Bの始点は `(0,0.9,-25)`、立哨Aは `(-4,0.9,-15)`。敵4体の役割は変更しない。
- 密書は `(16,1,-64)`。収納覆い `(14,0.9,-62.5)` と離し、同じE入力が死体の再取り出しと密書取得を同時に実行しない。死体を担いだままの密書取得も認めない。
- 門前の二回目の石の目印は `(4,0.07,-59)`。最初の誘導後に移動した立哨にも聞こえる位置とする。出口への曲がり角は一度z=-67へ出てから西へ曲がる。
- 屋根ClimbEdgeのtop_offsetは `(-1,3,-3)`。登攀中は前進入力を使う。屋根上の着地点を内側へ置き、地上通路の側柵は高さ2mとして屋根通行を妨げない。西側出口には6段の下降足場を設け、屋根から着地点までの空隙への落下を避ける。
- z=-20/-40、小屋入口 `(12,0.9,-51)`、出口 `(12,0.9,-67)` のCheckpointAreaに、NPC4体・MissionDirector・学習済みprefix・灯り・収納関係を `tutorial_world` namespaceで補完する。NPC集合、型、範囲、目標と標的死亡の整合を全検査してからfresh sceneへ復元する。
- `HideSpot.restore_stored_body(body)` はcheckpoint専用public API。生存中/他収納先/占有済みbodyを拒否し、既存carry/storageの所有権遷移を再利用する。通常操作による収納条件は維持する。
- 共通 `GameText.binding_text` / `with_bindings` をtutorialとHUDが共有する。設定で変更した実InputMapのキーを再表示し、Physical等の内部名を利用者向け案内に出さない。

初期実装は2026-09-07の旧方針下で開始された。2026-09-08再開後の振る舞い修正はred→greenで記録した。共通の敵視点修正は#36、checkpoint基盤は#31/#40、画面/設定は#36/#37の成果を統合し、チュートリアルに同じ機能を再実装しない。SUSPICIOUSの実移動欠落は石誘導を成立させる前提修正として独立コミットに分ける。
