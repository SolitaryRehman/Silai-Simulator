extends Node3D

@onready var camera_3d: Camera3D = $Camera3D

@onready var character_1: CharacterBody3D = $Character_1
@onready var animation_player: AnimationPlayer = $Character_1/armor/GeneralSkeleton/AnimationPlayer
@onready var back_sword: Node3D = $Character_1/armor/back_sword
@onready var hand_sword: Node3D = $Character_1/armor/GeneralSkeleton/BoneAttachment3D/hand_sword

@onready var continue_button: Button = $CanvasLayer/TextureRect/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/TextureRect/NewGameButton
@onready var game_options_button: Button = $CanvasLayer/TextureRect/GameOptionsButton
@onready var quit_game_button: Button = $CanvasLayer/TextureRect/QuitGameButton

var sword_drawn: bool = false
var is_animating: bool = false  # prevents spamming animations

func _ready():
	# Initial sword state
	back_sword.visible = true
	hand_sword.visible = false

	# Start in idle
	animation_player.play("idle_2/mixamo_com")

	# Connect all buttons hover → draw sword
	continue_button.mouse_entered.connect(_on_any_button_hovered)
	new_game_button.mouse_entered.connect(_on_any_button_hovered)
	game_options_button.mouse_entered.connect(_on_any_button_hovered)
	quit_game_button.mouse_entered.connect(_on_any_button_hovered)

	# Connect button clicks
	continue_button.pressed.connect(_on_continue_pressed)
	#new_game_button.pressed.connect(_on_new_game_pressed)
	game_options_button.pressed.connect(_on_game_options_pressed)
	quit_game_button.pressed.connect(_on_quit_pressed)


# ─── HOVER — triggers draw sequence once ───────────────────────────────────

func _on_any_button_hovered():
	if sword_drawn or is_animating:
		return
	is_animating = true
	await draw_sword_sequence()


func draw_sword_sequence():
	animation_player.play("sword_draw/mixamo_com")

	# Change 1.2 to the exact second his hand grabs the sword in your animation
	await get_tree().create_timer(0.2).timeout
	back_sword.visible = false
	hand_sword.visible = true

	await animation_player.animation_finished
	sword_drawn = true
	is_animating = false
	animation_player.play("sword_before_attack_idle/sword_before_idle_mixamo_com")


# ─── BUTTON CLICKS ──────────────────────────────────────────────────────────

func _on_continue_pressed():
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


#func _on_new_game_pressed():
	## Change to your new game scene
	#get_tree().change_scene_to_file("res://scenes/your_new_game_scene.tscn")


func _on_game_options_pressed():
	# Open options scene or panel
	pass


func _on_quit_pressed():
	if is_animating:
		await animation_player.animation_finished
	is_animating = true

	# If somehow quit is pressed before sword is drawn, draw first then quit
	if not sword_drawn:
		await draw_sword_sequence()

	await quit_sequence()


func quit_sequence():
	animation_player.play("Sword_Attack")
	await animation_player.animation_finished

	animation_player.play("Sword_Idle")

	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
