# Issue #37: Save and Settings

M6、起点main cb4ba25。TSK-1351登録と公開・Vault記録は親担当。本書は既存実装をベースラインとした今回以後の追加指示書。

## ACと担当

| AC | 実装・検証 |
|---|---|
| 安全保存 | user://save.jsonを検証してtemp/flush/readback/rename。不明version・型不正・読み取り/backup失敗で原本上書き禁止。失敗statusを公開 |
| best rank | より良いrank、同rankなら高scoreを保持。初回clearのみunlock。#36 MissionSelectがcampaign.mission_resultsを参照 |
| 設定保存適用 | Main配下SettingsControllerがmaster/BGM/SE、感度、全project action key/mouse remap、qualityを実反映。SettingsPanelは保存失敗を表示 |
| roundtrip | isolated test prefixでsave/load/apply、v1移行・futureversion・型破損・rename failure・backup復旧・best保持・競合をテスト |
| API | docs08§5/§10、docs09§8。既存void署名維持、status補助API。新規autoloadなし |

SaveManager、SettingsController/Panel、PlayerCameraRig倍率、tests、docs08/saveexample、本書を担当。#36はMain/SceneDirector入口・GameText・ja.csvを所有。SettingsPanel.configure(controller)、closed signalで接続しCSV同時編集はしない。#31checkpointはdictionary/nullのみ検証し内部を再解釈しない。

## 保存契約と手順

load_save/commitはvoidを保持しlast_error:Error,last_status:StringNameを追加。不明version/型不正は原本を残し書込block。malformedは一意corrupt backupへの退避成功時だけdefaultsへ復旧。v1欠損はdefaultsを補完するが型不正を見逃さない。tmp/bakも同じschema検証を通す。

1. memory schemaを検証しtmp書込/flush/readback後、既存finalをbakへ移す
2. 既存bakを削除せず一意な履歴名で保持する
3. tmp→final失敗はbak→finalのrollbackを試し、失敗時もbakを残してstatus通知
4. filesystem wrapper overrideでrename失敗を再現し、実saveに触れないテストを追加
5. 親がdata loss範囲だけ一度review、指摘をfocusedで確認してcommitへ

## 設定契約

version2へ任意fieldを追加し欠損はdefaultsで互換補完。sensitivity=0.5がCameraConfig基準倍率1、X/Y=1と反転を保存。volumeは0..1。quality low/medium/highはViewport scaling/MSAA、fullscreen/vsyncはDisplayServerへ適用。

input_overridesはaction→{type:key|mouse,code:int}。全ProjectSettings input actionを対象、Godot組込みUI actionは除外。毎回ProjectSettings既定から復元して適用し、gamepadはkeyboard/mouse remapで消さない。既定の文脈共用buttonは維持、変更で新たに生じる競合は拒否する。UI文言は#36 GameText key経由で外部化。

## 検証

Godot4.3 officialでSaveManager/Settings/PlayerCamera focusedと統合fullを一回。diff check、失敗ケースraw logとsnapshot identityをprivate evidenceへ保存。source commitまで、push/PR/Vaultは親担当。残りのdocs09設定項目の担当は親と調整し未実装を完了表示しない。

## 後続機能への追跡

| 未実装の出力・設定 | 既存Issueでの受入 |
|---|---|
| パッド振動、HUD縮小、内語表示 | #47/#59で出力の実装と設定接続、#49で受入 |
| 明るさの基準画像と校正 | #45 lightingの実装、#49で暗所の受入 |

これらは全Issue対応から除外しない。今回有効そうな未接続toggleを出さない。X/Y倍率・Y反転・fullscreen/vsyncは今回実装する。
