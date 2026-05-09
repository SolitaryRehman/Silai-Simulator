# shop.gd
extends Node3D

@onready var enter_image: TextureRect = $PauseCanvas/EnterImage
@onready var open_button: Button      = $PauseCanvas/EnterImage/OpenButton

@onready var hud_texture:  TextureRect = $PauseCanvas/HudTexture
@onready var level_label:  Label       = $PauseCanvas/HudTexture/LevelLabel
@onready var xp_label:     Label       = $PauseCanvas/HudTexture/XPLabel
@onready var coins_label:  Label       = $PauseCanvas/HudTexture/CoinLabel

@onready var sewing_machine: StaticBody3D = $sewing_machine

@export var customer_scene_berserker: PackedScene
@export var customer_scene_girl:      PackedScene

var _customer_active: bool = false
var _spawn_girl_next: bool = false

var _spawn_timer: Timer


func _ready() -> void:
	open_button.toggle_mode    = true
	open_button.button_pressed = false
	open_button.text           = "OFF"
	open_button.toggled.connect(_on_allow_customer_pressed)  # use toggled instead of pressed

	_spawn_timer          = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_spawn_customer)
	add_child(_spawn_timer)

	GameManager.stats_changed.connect(_refresh_hud)
	_refresh_hud()

	sewing_machine.sewing_complete.connect(_on_sewing_complete)
	
	 # ── Fade in from black ─────────────────────────────────────────────
	var black_rect = ColorRect.new()
	black_rect.color = Color(0, 0, 0, 1)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$PauseCanvas.add_child(black_rect)

	var tween = create_tween()
	tween.tween_property(black_rect, "color", Color(0, 0, 0, 0), 1.0)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(black_rect.queue_free)


# HUD
func _refresh_hud() -> void:
	level_label.text  = str(GameManager.player_level)
	xp_label.text     = str(GameManager.player_xp)
	coins_label.text  = str(GameManager.player_coins)


# Button — starts the arrival timer only if no customer is present or waiting
func _on_allow_customer_pressed(pressed: bool) -> void:
	if not pressed:
		return  # ignore the untoggle click
	if _customer_active or not _spawn_timer.is_stopped():
		# Reset button back to OFF — nothing is happening
		open_button.button_pressed = false
		open_button.text           = "OFF"
		return
	open_button.text = "ON"
	_spawn_timer.start(randf_range(3.0, 10.0))


func _spawn_customer() -> void:
	# Reset button to OFF now that the customer is arriving
	open_button.button_pressed = false
	open_button.text           = "OFF"

	var customer

	if _spawn_girl_next:
		customer       = customer_scene_girl.instantiate()
		customer.scale = Vector3(1.2, 1.2, 1.2)
	else:
		customer       = customer_scene_berserker.instantiate()
		customer.scale = Vector3(1.3, 1.3, 1.3)

	_spawn_girl_next = not _spawn_girl_next

	add_child(customer)
	customer.global_position = Vector3(9.56, 0.0, -1.0)
	customer.customer_left.connect(_on_customer_left, CONNECT_ONE_SHOT)

	_customer_active = true


func _on_customer_left() -> void:
	_customer_active = false


# UI visibility during cutting / sewing
func on_cutting_started() -> void:
	enter_image.visible = false
	hud_texture.visible = false


func _on_sewing_complete() -> void:
	await get_tree().create_timer(0.6).timeout
	enter_image.visible = true
	hud_texture.visible = true
