extends Node3D


## Observes production components; never drives their states or timers.
const PHASE_NAMES := ["平常", "不審", "捜索", "戦闘", "帰投"]

@onready var guard: EnemyBase = $Guard
@onready var player: PlayerController = $Player
@onready var status: Label = $Instructions/Panel/Text

var _saw_combat := false
var _saw_hidden := false
var _saw_search := false
var _saw_return := false
var _saw_recovered := false


func _ready() -> void:
	guard.brain().state_changed.connect(_on_guard_state_changed)


func _on_guard_state_changed(_previous: int, current: int) -> void:
	if current == Enums.AlertState.COMBAT:
		_saw_combat = true
	elif current == Enums.AlertState.SEARCHING and _saw_combat:
		_saw_search = true
	elif current == Enums.AlertState.RETURN and _saw_search:
		_saw_return = true
	elif current == Enums.AlertState.UNAWARE and _saw_return:
		_saw_recovered = true


func _process(_delta: float) -> void:
	if _saw_combat and player.is_hidden():
		_saw_hidden = true
	var brain := guard.brain()
	var completed := _saw_hidden and _saw_recovered and guard.is_assassinated()
	status.text = (
		"再潜伏ジム — WASD: 移動 / マウス: 視点 / C: しゃがむ / Shift: 走る\n"
		+ "正面で発見 → 壁を回って緑の退避地点で E → 帰投を待つ\n"
		+ "E で退出 → しゃがんで背後へ → F で必殺（再試行はシーン再起動）\n"
		+ "警戒: %s  |  プレイヤー: %s  |  残留警戒: ×%.1f / %.1f 秒\n"
		% [PHASE_NAMES[brain.alert_state()], player.state_machine.current_state(),
			brain.vigilance_multiplier(), brain.return_vigilance_remaining()]
		+ ("連鎖達成: 発見 → 隠れる → 捜索 → 帰投 → 背後必殺" if completed else
			"捜索は 60 秒、残留警戒は帰投開始から 120 秒。視認されたまま隠れることはできません。")
	)
