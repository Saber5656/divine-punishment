extends Node3D


## Observes production components; never drives their states or timers.
const PHASE_KEYS := [&"phase.unaware", &"phase.suspicious", &"phase.searching", &"phase.combat", &"phase.return"]

@onready var guard: EnemyBase = $Guard
@onready var player: PlayerController = $Player
@onready var status: Label = $Instructions/Panel/Text

var _saw_combat := false
var _saw_hidden := false
var _saw_search := false
var _saw_return := false
var _saw_recovered := false


func _ready() -> void:
	$HideSpot/Label.text = GameText.with_bindings(&"gym.hide")
	status.text = GameText.get_text(&"gym.title")
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
	status.text = GameText.with_bindings(&"gym.instructions") + (
		GameText.get_text(&"gym.status") % [GameText.get_text(PHASE_KEYS[brain.alert_state()]), player.state_machine.current_state(),
		brain.vigilance_multiplier(), brain.return_vigilance_remaining()]
	) + GameText.get_text(&"gym.complete" if completed else &"gym.pending")
