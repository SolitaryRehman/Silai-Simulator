extends Node3D


@onready var enter_image: TextureRect = $PauseCanvas/EnterImage
@onready var open_button: Button = $PauseCanvas/EnterImage/OpenButton

@onready var hud_texture: TextureRect = $PauseCanvas/HudTexture
@onready var level_label: Label = $PauseCanvas/HudTexture/LevelLabel
@onready var xp_label: Label = $PauseCanvas/HudTexture/XPLabel
@onready var coins_label: Label = $PauseCanvas/HudTexture/CoinLabel


@onready var sewing_machine: StaticBody3D = $sewing_machine


@export var customer_scene_berserker: PackedScene
@export var customer_scene_girl: PackedScene


var _shop_open: bool       = false
var _customer_active: bool = false
var _spawn_girl_next: bool = false   # false = berserker first

var _spawn_timer: Timer


func _ready() -> void:
	open_button.toggle_mode    = true
	open_button.button_pressed = false
	open_button.text           = "OFF"
	open_button.toggled.connect(_on_btn_toggled)

	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_spawn_customer)
	add_child(_spawn_timer)
	
	# Connect to GameManager so HUD updates whenever XP / coins change
	GameManager.stats_changed.connect(_refresh_hud)

	_refresh_hud()
	
	sewing_machine.sewing_complete.connect(_on_sewing_complete)


# ─────────────────────────────────────────────────────────────────────────────
# HUD
# ─────────────────────────────────────────────────────────────────────────────

func _refresh_hud() -> void:
	# ── Swap these three lines for Database calls when ready ──────────────────
	var level: int = GameManager.player_level
	var xp:    int = GameManager.player_xp
	var coins: int = GameManager.player_coins
	# ── e.g. var level: int = Database.get_player_level() ────────────────────

	level_label.text = str(level)
	xp_label.text    = str(xp)
	coins_label.text = str(coins)


# ─────────────────────────────────────────────────────────────────────────────
# Shop toggle
# ─────────────────────────────────────────────────────────────────────────────

func _on_btn_toggled(pressed: bool) -> void:
	_shop_open = pressed
	if pressed:
		open_button.text = "ON"
		_spawn_timer.start(randf_range(3.0, 15.0))
	else:
		open_button.text = "OFF"
		_spawn_timer.stop()


func _spawn_customer() -> void:
	if not _shop_open:
		return

	if _customer_active:
		_close_shop()
		return

	var customer

	if _spawn_girl_next:
		customer = customer_scene_girl.instantiate()
		customer.scale = Vector3(1.2, 1.2, 1.2)
	else:
		customer = customer_scene_berserker.instantiate()
		customer.scale = Vector3(1.3, 1.3, 1.3)

	_spawn_girl_next = not _spawn_girl_next   # flip for next time

	add_child(customer)
	customer.global_position = Vector3(9.56, 0.0, -1.0)
	customer.customer_left.connect(_on_customer_left, CONNECT_ONE_SHOT)

	_customer_active = true
	_close_shop()


func _on_customer_left() -> void:
	_customer_active = false
	_refresh_hud()   # coins/xp may have changed after order completion


func _close_shop() -> void:
	_shop_open                 = false
	open_button.button_pressed = false
	open_button.text           = "OFF"


func on_cutting_started() -> void:
	enter_image.visible = false
	hud_texture.visible = false


func _on_sewing_complete() -> void:
	# Wait for camera tween to finish returning to player
	# Adjust this delay to match your camera transition duration
	await get_tree().create_timer(0.6).timeout
	enter_image.visible = true
	hud_texture.visible = true
