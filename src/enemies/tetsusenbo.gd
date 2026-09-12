class_name Tetsusenbo
extends TargetNpc

const COUNTER_WINDOW := 1.2
var _counter_remaining := 0.0

func counter_remaining() -> float:
	return _counter_remaining

func restore_counter_remaining(value: float) -> bool:
	if not is_finite(value) or value < 0.0 or value > COUNTER_WINDOW: return false
	_counter_remaining = value
	return true

func _ready() -> void:
	super._ready()
	EventBus.combat_parried.connect(_on_parried)

func _exit_tree() -> void:
	if EventBus.combat_parried.is_connected(_on_parried): EventBus.combat_parried.disconnect(_on_parried)
	super._exit_tree()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_finite(delta) and delta >= 0.0:
		_counter_remaining = maxf(0.0,_counter_remaining-delta)

func receive_combat_damage(amount: int,source: Node = null) -> int:
	if (source is PlayerCombat or source is PlayerController) and _counter_remaining <= 0.0:
		return 0
	return super.receive_combat_damage(amount,source)

func _on_parried(_player: Node,attacker: Node) -> void:
	# Existing combat events carry the attack component as their source.
	if attacker in [self,combat()] and not is_defeated():
		_counter_remaining = COUNTER_WINDOW
