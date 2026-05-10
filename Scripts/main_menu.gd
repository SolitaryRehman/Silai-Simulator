extends Node3D

# grab everything we need from the scene tree upfront
@onready var camera_3d: Camera3D = $Camera3D

@onready var character_1: CharacterBody3D = $Character_1
@onready var animation_player: AnimationPlayer = $Character_1/armor/GeneralSkeleton/AnimationPlayer

@onready var general_skeleton: Skeleton3D = %GeneralSkeleton
# sword on the character's back until the player hovers a button
@onready var back_sword: Node3D = $Character_1/armor/GeneralSkeleton/BoneAttachment3D2/back_sword
# sword that appears in the hand after the draw animation plays
@onready var hand_sword: Node3D = $Character_1/armor/GeneralSkeleton/BoneAttachment3D/hand_sword

@onready var continue_button: Button = $CanvasLayer/TextureRect/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/TextureRect/NewGameButton
@onready var game_options_button: Button = $CanvasLayer/TextureRect/GameOptionsButton
@onready var quit_game_button: Button = $CanvasLayer/TextureRect/QuitGameButton

# tracks whether the sword is already out so we don't retrigger the draw
var sword_drawn: bool = false
# blocks input while a draw or attack animation is mid-play
var is_animating: bool = false
# stops hover events from interrupting an in-progress button transition
var is_transitioning: bool = false

# remembers which button the character is currently posing for
var current_button: int = -1

# pure rotation, no scale baked in — keeps slerp from going haywire
var original_rotation: Basis
var target_rotation: Basis

# saved once so slerp never accidentally squishes or stretches the character
var character_scale: Vector3

# one idle animation per button slot — character shifts pose as you move the mouse
const BUTTON_ANIMATIONS: Array[String] = [
	"1st idle main",
	"2nd idle main",
	"3rd idle main",
]


func _ready():
	# save scale and starting rotation before we ever touch the basis
	character_scale    = character_1.scale
	original_rotation  = character_1.basis.orthonormalized()
	target_rotation    = original_rotation

	# sword starts sheathed on the back
	back_sword.visible = true
	hand_sword.visible = false

	animation_player.play("idle_2/mixamo_com")

	# these fire the sword draw the first time any button is hovered
	continue_button.mouse_entered.connect(_on_any_button_hovered)
	new_game_button.mouse_entered.connect(_on_any_button_hovered)
	game_options_button.mouse_entered.connect(_on_any_button_hovered)
	quit_game_button.mouse_entered.connect(_on_any_button_hovered)

	# these shift the character's idle pose to match whichever button is active
	continue_button.mouse_entered.connect(func():     _on_button_hovered(0))
	new_game_button.mouse_entered.connect(func():     _on_button_hovered(1))
	game_options_button.mouse_entered.connect(func(): _on_button_hovered(2))
	quit_game_button.mouse_entered.connect(func():    _on_button_hovered(3))

	continue_button.pressed.connect(_on_continue_pressed)
	game_options_button.pressed.connect(_on_game_options_pressed)
	quit_game_button.pressed.connect(_on_quit_pressed)
	
	# slap a black rect on top and fade it out so the menu doesn't just pop in
	var black_rect = ColorRect.new()
	black_rect.color = Color(0, 0, 0, 1)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(black_rect)

	var tween = create_tween()
	tween.tween_property(black_rect, "color", Color(0, 0, 0, 0), 1.0)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(black_rect.queue_free)


func _process(delta):
	# smoothly slerp toward the target rotation every frame without touching scale
	var current_rot = character_1.basis.orthonormalized()
	var new_rot     = current_rot.slerp(target_rotation, delta * 6.0)
	# manually bolt the saved scale back on after slerp since it strips it
	character_1.basis = Basis(
		new_rot.x * character_scale.x,
		new_rot.y * character_scale.y,
		new_rot.z * character_scale.z
	)


func _on_button_hovered(button_idx: int):
	# sword has to be out before any pose changes make sense
	if not sword_drawn:
		return
	# already here, nothing to do
	if button_idx == current_button:
		return
	# let the current transition finish before starting a new one
	if is_transitioning:
		return

	# quit button makes the character dramatically face the camera
	if button_idx == 3:
		face_camera()
	else:
		target_rotation = original_rotation

	var from := current_button
	current_button = button_idx
	_play_transition_sequence(from, button_idx)


func _play_transition_sequence(from: int, to: int):
	# nothing to transition from if no button was previously active
	if from == -1:
		return

	is_transitioning = true

	# play forward or backward depending on which direction the mouse moved
	if to > from:
		for i in range(from, to):
			animation_player.play(BUTTON_ANIMATIONS[i])
			await animation_player.animation_finished
	else:
		for i in range(from - 1, to - 1, -1):
			animation_player.play_backwards(BUTTON_ANIMATIONS[i])
			await animation_player.animation_finished

	is_transitioning = false


func face_camera():
	# flatten to the horizontal plane so the character doesn't tilt its head up
	var dir = camera_3d.global_position - character_1.global_position
	dir.y = 0
	if dir.length() > 0.01:
		var saved = character_1.basis
		# look_at flips the facing direction, so we negate dir to correct it
		character_1.look_at(character_1.global_position - dir, Vector3.UP)
		target_rotation = character_1.basis.orthonormalized()
		# restore immediately so slerp handles the actual turning smoothly
		character_1.basis = saved


func _on_any_button_hovered():
	# only draw the sword once, and don't interrupt if it's already mid-draw
	if sword_drawn or is_animating:
		return
	is_animating = true
	await draw_sword_sequence()


func draw_sword_sequence():
	animation_player.play("sword_draw/mixamo_com")
	# swap the visible sword mesh partway through so it feels like a real grab
	await get_tree().create_timer(0.2).timeout
	back_sword.visible = false
	hand_sword.visible = true
	await animation_player.animation_finished
	sword_drawn = true
	is_animating = false
	# default starting pose maps to the first button slot
	current_button = 0
	animation_player.play("sword_before_attack_idle/sword_before_idle_mixamo_com")


func _on_continue_pressed():
	# fade to black before switching scenes so it doesn't hard-cut
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
	# wait for any current animation to finish so we don't cut it mid-swing
	if is_animating:
		await animation_player.animation_finished
	is_animating = true
	# draw the sword first if the player quit without hovering anything
	if not sword_drawn:
		await draw_sword_sequence()
	await quit_sequence()


func quit_sequence():
	animation_player.play("Sword_Attack")

	# lunge the character forward a bit to sell the attack
	var forward = -character_1.global_transform.basis.z.normalized()
	var start_pos = character_1.global_position
	var end_pos   = start_pos - forward * 1.0
	var lunge_tween = create_tween()
	lunge_tween.tween_property(character_1, "global_position", end_pos, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await animation_player.animation_finished

	# tilt the camera upward like the player just got knocked down
	var cam_tween = create_tween()
	cam_tween.tween_property(camera_3d, "rotation_degrees:x", 60.0, 1.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# bleed a red overlay in at the same time for a death-screen feel
	var red_rect = ColorRect.new()
	red_rect.color = Color(1, 0, 0, 0)
	red_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer.add_child(red_rect)

	var red_tween = create_tween()
	red_tween.tween_property(red_rect, "color", Color(1, 0, 0, 1), 1.5)\
		.set_trans(Tween.TRANS_LINEAR)

	await red_tween.finished

	get_tree().quit()
