extends Node3D

@onready var camera_3d: Camera3D = $Camera3D

@onready var character_1: CharacterBody3D = $Character_1
@onready var animation_player: AnimationPlayer = $Character_1/armor/GeneralSkeleton/AnimationPlayer

@onready var general_skeleton: Skeleton3D = %GeneralSkeleton
@onready var back_sword: Node3D = $Character_1/armor/GeneralSkeleton/BoneAttachment3D2/back_sword
@onready var hand_sword: Node3D = $Character_1/armor/GeneralSkeleton/BoneAttachment3D/hand_sword

@onready var continue_button: Button = $CanvasLayer/TextureRect/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/TextureRect/NewGameButton
@onready var game_options_button: Button = $CanvasLayer/TextureRect/GameOptionsButton
@onready var quit_game_button: Button = $CanvasLayer/TextureRect/QuitGameButton

var sword_drawn: bool = false
var is_animating: bool = false
var is_transitioning: bool = false

var current_button: int = -1

# Rotation-only bases (normalized, no scale)
var original_rotation: Basis
var target_rotation: Basis

# Scale saved once, never touched again
var character_scale: Vector3

const BUTTON_ANIMATIONS: Array[String] = [
	"1st idle main",
	"2nd idle main",
	"3rd idle main",
]


func _ready():
	character_scale    = character_1.scale
	original_rotation  = character_1.basis.orthonormalized()
	target_rotation    = original_rotation

	back_sword.visible = true
	hand_sword.visible = false

	animation_player.play("idle_2/mixamo_com")

	continue_button.mouse_entered.connect(_on_any_button_hovered)
	new_game_button.mouse_entered.connect(_on_any_button_hovered)
	game_options_button.mouse_entered.connect(_on_any_button_hovered)
	quit_game_button.mouse_entered.connect(_on_any_button_hovered)

	continue_button.mouse_entered.connect(func():     _on_button_hovered(0))
	new_game_button.mouse_entered.connect(func():     _on_button_hovered(1))
	game_options_button.mouse_entered.connect(func(): _on_button_hovered(2))
	quit_game_button.mouse_entered.connect(func():    _on_button_hovered(3))

	continue_button.pressed.connect(_on_continue_pressed)
	game_options_button.pressed.connect(_on_game_options_pressed)
	quit_game_button.pressed.connect(_on_quit_pressed)
	
	# ── Fade in from black ─────────────────────────────────────────────
	var black_rect = ColorRect.new()
	black_rect.color = Color(0, 0, 0, 1)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(black_rect)

	var tween = create_tween()
	tween.tween_property(black_rect, "color", Color(0, 0, 0, 0), 1.0)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(black_rect.queue_free)  # clean up after fade

# ─── SMOOTH CHARACTER ROTATION ───────────────────────────────────────────────

func _process(delta):
	# Slerp rotation only (both normalized = no scale = no quaternion error)
	var current_rot = character_1.basis.orthonormalized()
	var new_rot     = current_rot.slerp(target_rotation, delta * 6.0)
	# Reapply scale manually after slerp
	character_1.basis = Basis(
		new_rot.x * character_scale.x,
		new_rot.y * character_scale.y,
		new_rot.z * character_scale.z
	)


# ─── BUTTON HOVER TRANSITION ─────────────────────────────────────────────────

func _on_button_hovered(button_idx: int):
	if not sword_drawn:
		return
	if button_idx == current_button:
		return
	if is_transitioning:
		return

	if button_idx == 3:
		face_camera()
	else:
		target_rotation = original_rotation

	var from := current_button
	current_button = button_idx
	_play_transition_sequence(from, button_idx)


func _play_transition_sequence(from: int, to: int):
	if from == -1:
		return

	is_transitioning = true

	if to > from:
		for i in range(from, to):
			animation_player.play(BUTTON_ANIMATIONS[i])
			await animation_player.animation_finished
	else:
		for i in range(from - 1, to - 1, -1):
			animation_player.play_backwards(BUTTON_ANIMATIONS[i])
			await animation_player.animation_finished

	is_transitioning = false


# ─── FACE CAMERA ─────────────────────────────────────────────────────────────

func face_camera():
	var dir = camera_3d.global_position - character_1.global_position
	dir.y = 0
	if dir.length() > 0.01:
		var saved = character_1.basis
		# look_at the camera directly so the character faces it
		character_1.look_at(character_1.global_position - dir, Vector3.UP)
		target_rotation = character_1.basis.orthonormalized()
		character_1.basis = saved  # restore while slerp smoothly transitions


# ─── HOVER (sword draw) ───────────────────────────────────────────────────────

func _on_any_button_hovered():
	if sword_drawn or is_animating:
		return
	is_animating = true
	await draw_sword_sequence()


func draw_sword_sequence():
	animation_player.play("sword_draw/mixamo_com")
	await get_tree().create_timer(0.2).timeout
	back_sword.visible = false
	hand_sword.visible = true
	await animation_player.animation_finished
	sword_drawn = true
	is_animating = false
	current_button = 0
	animation_player.play("sword_before_attack_idle/sword_before_idle_mixamo_com")


# ─── BUTTON CLICKS ───────────────────────────────────────────────────────────

func _on_continue_pressed():
	var black_rect = ColorRect.new()
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(black_rect)

	var tween = create_tween()
	tween.tween_property(black_rect, "color", Color(0, 0, 0, 1), 1.5)\
		.set_trans(Tween.TRANS_LINEAR)

	await tween.finished
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

	# ── 1. Lunge forward 1 metre in 0.3s ──────────────────────────────
	var forward = -character_1.global_transform.basis.z.normalized()
	var start_pos = character_1.global_position
	var end_pos   = start_pos - forward * 1.0
	var lunge_tween = create_tween()
	lunge_tween.tween_property(character_1, "global_position", end_pos, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await animation_player.animation_finished

	# ── 2. Camera tilts upward (death fall effect) ─────────────────────
	var cam_tween = create_tween()
	cam_tween.tween_property(camera_3d, "rotation_degrees:x", 60.0, 1.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# ── 3. Red overlay fades in over 1.5s at the same time ─────────────
	var red_rect = ColorRect.new()
	red_rect.color = Color(1, 0, 0, 0)
	red_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(red_rect)

	var red_tween = create_tween()
	red_tween.tween_property(red_rect, "color", Color(1, 0, 0, 1), 1.5)\
		.set_trans(Tween.TRANS_LINEAR)

	await red_tween.finished

	get_tree().quit()
