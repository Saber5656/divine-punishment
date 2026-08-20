class_name PlayerController
extends CharacterBody3D


@export var player_profile: PlayerProfile

@onready var state_machine: PlayerStateMachine = $StateMachine as PlayerStateMachine


func _ready() -> void:
	if player_profile != null:
		state_machine.player_profile = player_profile


func _physics_process(delta: float) -> void:
	_update_state_from_input()
	_apply_gravity(delta)
	_apply_movement()
	move_and_slide()


func current_movement_params() -> Dictionary:
	return state_machine.movement_params()


func _update_state_from_input() -> void:
	if not Input.is_action_pressed(&"sprint") and state_machine.current_state() == PlayerStateMachine.STATE_SPRINT:
		state_machine.resume_from_sprint()

	if Input.is_action_just_pressed(&"stance_toggle"):
		match state_machine.current_state():
			PlayerStateMachine.STATE_GROUND:
				state_machine.change_state(PlayerStateMachine.STATE_CROUCH)
			PlayerStateMachine.STATE_CROUCH:
				state_machine.change_state(PlayerStateMachine.STATE_GROUND)

	if Input.is_action_pressed(&"sprint"):
		state_machine.change_state(PlayerStateMachine.STATE_SPRINT)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity += get_gravity() * delta


func _apply_movement() -> void:
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := transform.basis * local_direction
	world_direction.y = 0.0
	if world_direction.length_squared() > 0.0:
		world_direction = world_direction.normalized() * input_vector.length()

	var speed := float(state_machine.movement_params().get(&"speed", 0.0))
	velocity.x = world_direction.x * speed
	velocity.z = world_direction.z * speed
