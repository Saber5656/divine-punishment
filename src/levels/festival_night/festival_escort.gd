extends EscortGuard

## The festival schedule owns movement; EscortGuard still owns its principal's
## defeat signal, one-shot reaction, pending wake-up and checkpoint bookkeeping.
func _ready() -> void:
	super._ready()
	brain().set_routine_type(&"patrol")
	brain().set_routine_enabled(true)

func _physics_process(_delta: float) -> void:
	var principal := escort_target()
	if principal != null and principal.is_target_defeated():
		_enter_target_combat()
