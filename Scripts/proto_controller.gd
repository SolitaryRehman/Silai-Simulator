extends CharacterBody3D
 
## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false
 
@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 7.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0
 
@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"
 
var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false
 
# ── NEW: Tailor variables ──────────────────────────────
var in_minigame : bool = false
var original_head_rotation : Vector3
var original_player_position : Vector3
# ──────────────────────────────────────────────────────
 
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var camera: Camera3D = $Head/Camera3D
 
 
func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
 
	# Connect to GameManager signals
	GameManager.order_received.connect(_on_order_received)
	GameManager.garment_sewn.connect(_on_garment_sewn)
	
	# TEMP: small delay so GameManager is fully ready
	await get_tree().create_timer(0.5).timeout
	GameManager.receive_order("tshirt")
 
 
func _unhandled_input(event: InputEvent) -> void:
	# Don't process normal input during minigame
	if in_minigame:
		return
 
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
 
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)
 
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()
 
 
func _physics_process(delta: float) -> void:
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
 
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta
 
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity
 
	if can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed
 
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.z = 0
 
	move_and_slide()
 
 
# ════════════════════════════════════════════════════
#  TAILOR MINIGAME FUNCTIONS
# ════════════════════════════════════════════════════
 
## Called by CuttingTable / SewingTable to freeze the player
func lock_for_minigame():
	in_minigame = true
	can_move = false
	can_jump = false
	original_head_rotation = head.rotation
	original_player_position = global_position
	release_mouse()
 
 
## Called when minigame ends (complete or cancelled)
func unlock_from_minigame():
	in_minigame = false
	can_move = true
	can_jump = true
	capture_mouse()
 
 
## Smoothly move Head/Camera to a target Node3D transform
## Used by SewingTable to aim camera at sewing machine
func tween_camera_to(target: Node3D, duration: float = 0.7):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(head, "global_position", target.global_position, duration)
	tween.parallel().tween_property(head, "global_rotation", target.global_rotation, duration)
	return tween
 
 
## Restore camera back to the player's head position
func tween_camera_back(duration: float = 0.6):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(head, "position", Vector3(0, 0, 0), duration)
	tween.parallel().tween_property(head, "rotation", original_head_rotation, duration)
	return tween
 
 
func _on_order_received(_order_data):
	pass
 
 
func _on_garment_sewn(_garment_type):
	unlock_from_minigame()
 
 
# ════════════════════════════════════════════════════
#  ORIGINAL PROTOCONTROLLER FUNCTIONS
# ════════════════════════════════════════════════════
 
func rotate_look(rot_input : Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y -= rot_input.x * look_speed
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)
 
 
func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO
 
 
func disable_freefly():
	collider.disabled = false
	freeflying = false
 
 
func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
 
 
func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false
 
 
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
