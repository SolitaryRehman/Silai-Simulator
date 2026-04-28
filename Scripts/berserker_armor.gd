extends CharacterBody3D


@onready var animation_player: AnimationPlayer = $UAL1_Standard/AnimationPlayer

# --- Settings ---
@export var move_speed: float = 1.50
@export var target_z: float = 10.0       # Z position where the character stops
@export var walk_anim: String = "Walk"
@export var idle_anim: String = "idle_2/mixamo_com"

# --- Internal ---
var _walking: bool = true


func _ready() -> void:
	animation_player.play(walk_anim)


func _physics_process(delta: float) -> void:
	if not _walking:
		return

	# Move forward along +Z
	velocity = Vector3(0, 0, move_speed)
	move_and_slide()

	# Check if target reached
	if global_position.z >= target_z:
		global_position.z = target_z   # snap cleanly to the point
		velocity = Vector3.ZERO
		_walking = false
		animation_player.play(idle_anim)
