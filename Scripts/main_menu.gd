extends Node3D

@onready var camera_3d: Camera3D = $Camera3D
@onready var character_1: CharacterBody3D = $Character_1
@onready var animation_player: AnimationPlayer = $Character_1/armor/GeneralSkeleton/AnimationPlayer
@onready var back_sword: Node3D = $Character_1/armor/back_sword
@onready var general_skeleton: Skeleton3D = %GeneralSkeleton
@onready var hand_sword: Node3D = $Character_1/armor/GeneralSkeleton/BoneAttachment3D/hand_sword
@onready var continue_button: Button = $CanvasLayer/TextureRect/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/TextureRect/NewGameButton
@onready var game_options_button: Button = $CanvasLayer/TextureRect/GameOptionsButton
@onready var quit_game_button: Button = $CanvasLayer/TextureRect/QuitGameButton

var sword_drawn: bool = false
var is_animating: bool = false

var left_arm_idx: int = -1
var right_arm_idx: int = -1

# X axis pitch — NEGATIVE = arms tilt forward/up, POSITIVE = arms tilt back/down
# If arms go behind instead of forward, flip the sign of your angle values
var target_arm_angle: float = 0.0

# Character rotation targets — lerped smoothly in _process
var original_rotation: Basis
var target_character_basis: Basis
var is_facing_camera: bool = false


func _ready():
	original_rotation = character_1.basis
	target_character_basis = character_1.basis

	back_sword.visible = true
	hand_sword.visible = false

	left_arm_idx = general_skeleton.find_bone("LeftLowerArm")
	right_arm_idx = general_skeleton.find_bone("RightLowerArm")

	print("LeftLowerArm idx: ", left_arm_idx)
	print("RightLowerArm idx: ", right_arm_idx)

	animation_player.play("idle_2/mixamo_com")

	# Draw sword on first hover
	continue_button.mouse_entered.connect(_on_any_button_hovered)
	new_game_button.mouse_entered.connect(_on_any_button_hovered)
	game_options_button.mouse_entered.connect(_on_any_button_hovered)
	quit_game_button.mouse_entered.connect(_on_any_button_hovered)

	# Arm angles — tweak the numbers to taste
	# If arms go BEHIND instead of FORWARD, negate all four values
	continue_button.mouse_entered.connect(func(): aim_arms_normal(-30.0))
	new_game_button.mouse_entered.connect(func(): aim_arms_normal(-10.0))
	game_options_button.mouse_entered.connect(func(): aim_arms_normal(10.0))
	quit_game_button.mouse_entered.connect(func(): aim_arms_and_face_camera(30.0))

	continue_button.pressed.connect(_on_continue_pressed)
	game_options_button.pressed.connect(_on_game_options_pressed)
	quit_game_button.pressed.connect(_on_quit_pressed)


# ─── PROCESS ────────────────────────────────────────────────────────────────

func _process(delta):
	# Smoothly rotate character toward target basis — fixes the normalization error
	var current = character_1.basis.orthonormalized()
	var target  = target_character_basis.orthonormalized()
	character_1.basis = current.slerp(target, delta * 6.0)

	# Smoothly move arms
	if not sword_drawn:
		return
	if left_arm_idx == -1 or right_arm_idx == -1:
		return

	# Rotating around X axis (pitch).
	# If arms go behind the character, change Vector3.RIGHT → Vector3.LEFT
	var arm_target = Quaternion(Vector3.RIGHT, deg_to_rad(target_arm_angle))

	var current_l = general_skeleton.get_bone_pose_rotation(left_arm_idx)
	var current_r = general_skeleton.get_bone_pose_rotation(right_arm_idx)

	general_skeleton.set_bone_pose_rotation(left_arm_idx, current_l.slerp(arm_target, delta * 5.0))
	general_skeleton.set_bone_pose_rotation(right_arm_idx, current_r.slerp(arm_target, delta * 5.0))


# ─── AIM FUNCTIONS ──────────────────────────────────────────────────────────

func aim_arms_normal(angle_x: float):
	if not sword_drawn:
		return
	target_arm_angle = angle_x
	# Restore original facing — _process lerps toward this every frame
	target_character_basis = original_rotation


func aim_arms_and_face_camera(angle_x: float):
	if not sword_drawn:
		return
	target_arm_angle = angle_x

	# Build a facing basis toward the camera
	var dir = camera_3d.global_position - character_1.global_position
	dir.y = 0
	if dir.length() > 0.01:
		# look_at temporarily so we can grab its resulting basis
		var saved = character_1.basis
		character_1.look_at(character_1.global_position - dir, Vector3.UP)
		target_character_basis = character_1.basis.orthonormalized()
		# Restore immediately — _process will lerp to target smoothly
		character_1.basis = saved


# ─── HOVER ──────────────────────────────────────────────────────────────────

func _on_any_button_hovered():
	if sword_drawn or is_animating:
		return
	is_animating = true
	await draw_sword_sequence()


func draw_sword_sequence():
	animation_player.play("sword_draw/mixamo_com")
	await get_tree().create_timer(0.3).timeout
	back_sword.visible = false
	hand_sword.visible = true
	await animation_player.animation_finished
	sword_drawn = true
	is_animating = false
	animation_player.play("sword_before_attack_idle/sword_before_idle_mixamo_com")


# ─── BUTTON CLICKS ──────────────────────────────────────────────────────────

func _on_continue_pressed():
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _on_game_options_pressed():
	pass


func _on_quit_pressed():
	if is_animating:
		await animation_player.animation_finished
	is_animating = true
	if not sword_drawn:
		await draw_sword_sequence()
	await quit_sequence()


func quit_sequence():
	animation_player.play("Sword_Attack")
	await animation_player.animation_finished
	animation_player.play("Sword_Idle")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
