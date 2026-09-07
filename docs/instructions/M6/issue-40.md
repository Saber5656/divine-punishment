# Issue #40: 武家屋敷の敵・標的・脱出

起点: main `51f0d1bf7ec1dce4b68a69ca7021655b0aec14be`。#31 の `3bc004a` / `52dca42` をstackした既存checkpointを利用。先行grayboxは遡及的baselineであり、NPC spawn markerだけを実在する敵として扱わない。

## 正本と受入対応

1. docs/maps/m02-yashiki.md §3.2–3.4 と docs/04-level-design.md §3.4–3.6 を読む。平面座標は Godot x/z。高さは下記の縦断仕様を使用し、旧全員 y=0 の重複を継承しない。
2. 10体+標的: E1/E2正門、E3/E4庭の周回90秒、E5提灯8字120秒/警戒南庭、E6縁側60秒中10秒庭向き、E7廊下45秒、E8座敷で5分後交代、G1/G2随伴、TGT書院。既存marker identityと座標を使用。NPC・markerを重複生成しない。
3. 標的6分: 書院(58,19)0–120秒、廊下→厠(66,19)120–180秒、座敷2(52,13)180–300秒、書院へ300–360秒。移動時間をdwellに重ねず実測360秒周期。書院ではB頭上/C床下、厠ではA背後のproduction Resolverで必殺可能。護衛はtoilet分離tagで廊下待機。
4. 標的killでMissionDirectorのKILL_TARGET→ESCAPE。正門は警戒中に実collisionと視覚表示で閉じる。侵入経路逆走/西水路の別出口は残しsoftlockを防ぐ。escape Area3Dはlayer15/player mask、現在ESCAPEのときだけcompleteする。
5. CheckpointInsidePerimeter/CheckpointMainHouse/CheckpointTargetの3箇所。暗殺checkpointは近づいただけで成立しないようkill後にcapture。retry後に標的が復活したのに目標だけ脱出済み等の矛盾を作らない。checkpoint_reached eventでmission-local world stateをsnapshotへ補い、reload時に敵状態/目標と位置・忍具・警戒を一貫復元する。

## 所有と互換

- `src/levels/samurai_residence/samurai_mission.gd`（新規runtime）、`samurai_residence.tscn`、必要最小限の既存marker補完、`data/missions/m02.tres`、NPC routine data、関連focused/integration/smoke test、G3 QA記録。図面改訂が必要ならgeometry前に理由を記録。
- geometry builderをNPC AIやUIの所有者にしない。runtime childを追加しEditor hintでは動かさない。既存Main/SceneDirectorをautoloadへ移さない。
- #30 enemy navigation/return/hidden combat修正をmainから統合する。shared EnemyBrainの直接counter加算は#35で削除済み、再導入しない。
- #31 #36 #37の未統合sourceを捨てない。日本語表示はGameText/ja.csvの既存契約へ追加し新しい独自text loaderを作らない。

## 検証

focused: 実11NPC/配置/型/route移動、6分周期境界と実時刻、guard分離、未達成出口拒否、警戒門のcollision、3checkpoint往復とkill後再開。geometry既存契約を維持。

統合: Godot4.3 full GUTを変更一式に一回、PR GUTとmain3OS export/Linuxboot。G3aはA/B/Cの未発見clearを実入力で各1回（A忍具3以内/B0/C息切れなし）、標的実6分周回観察、基準18分±30%のプレイ実測。自動短縮/teleport/時刻加速はlogic試験に限定し実プレイ時間と混同しない。未実施を成功扱いしない。

記録: canonical TSK1351に目的/判断/結果/制限/sourceSHA/PR、source docs/qa-logs/G3-m02.mdに再現可能な操作・実測。通常review待ちは不要、G4/G5の別成果物を完了済み扱いしない。

scope外: art models/lighting/tuning最終値（#43–45/#41）、campaign/カットシーン、release。

## 着工前の縦断修正（2026-09-07）

standing radius 0.35 / height 1.8 の capsule を旧標的 (58,0,19) に置くと、GardenGravel・MainHouseFloor・CrawlUnderHouseFloor・CrawlUnderHouseRoof の4体と重なった。0.2 m の水平rayだけでは実キャラクターの通路を保証できない。地上・床下を分離し、collisionを無効にして回避しない。

| 層 | 床上面 Godot Y | actor root Y | 制約 |
|---|---|---|---|
| 庭・床下土 | -0.9 | 0.0 | standing底 -0.9、Crawl姿勢は同じ底位置で高さ0.7 |
| 母屋・縁側 | 0.4 | 1.3 | 床下面0.2、床下天井下面0.1。書院(58,1.3,19)はstandingが干渉しない |
| 屋根・梁 | 4.0 | 5.0 | 梁から標的まで4m以内、書院上の開口をrayが通る |

- 地上Aは縁側西側の実collision rampで1.3 m上る。NPC navも同じ勾配を通り、母屋navは actor中心の高さへ対応する。
- 床下Cは地上と同じ土に支持されるが、上の母屋床と天井を共有し通路高さを限定する。水路との連絡はCrawlEntranceと実通路で連続させる。庭の重複上積み床はactor足下と整合する高さへ揃える。
- 書院床の隙間は幅を限定した実開口に分割し、Crawl rootから標的rootへのbelow距離1.5m以内とray通過を確かめる。屋根も書院の小開口を設ける。床全面/天井全面のcollision無効化は禁止。
- 屋内NPC/marker/light/checkpointの高さを対応させる。屋外E5等の旧座標が家内部と衝突する場合は図面へ配置意図と実位置を記録する。
- route validatorはstanding/Crawlの実capsule形状（足元を保つoffsetを含む）で全waypointと移動segmentを調べる。実Playerの入力移動でもramp/床下接続を検証する。

## Runtime API・復元の契約

- mission childが11体をspawn markerごとに一度だけ作り、PatrolPath/RoutineStopを割り当てる。標的はactive_from/until時刻タグを使い、移動は各phase時間内に行い、dwellを足して360秒を超過させない。時計/位置は通常physicsのみで進める。
- MissionDirectorの既存公開start/current/completeを使う。UI所有者のSceneDirectorが既に開始している場合は二重resetしない。未開始のscene直接起動でも再現できる。
- snapshotにはmission内のstable NPC ID、位置・向き・生死/気絶・routine phase、mission objective/statsを記録。retry reloadで検証して復元し、標的死亡済みはkill eventの重複加算を避けてESCAPEと一貫させる。必要な共通snapshot APIは所有者と合意して追加する。
- 暗殺checkpointは接近時に無効、成功event後にcaptureする。gateとescapeはmission状態を毎回検査。新規UI文言はGameTextの既存契約を利用し、担当外のloaderを作らない。

## 実装中の確認（2026-09-08）

NPCの所有するMissionRoutineはtop_levelとし、移動・旋回でworld座標の巡回点と向きが動かないようにする。PatrolPathは2stop契約のため、立哨/休息は同一点のholdを2個持たせる。屋根取付き/池南岸の更新はmap§6参照。G3aはこの段階では未通過であり、fixtureによる境界試験を実360秒観察や未発見プレイと扱わない。
