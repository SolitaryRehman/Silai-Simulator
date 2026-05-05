extends Node3D

@export var customer_scene_berserker: PackedScene
@export var customer_scene_girl: PackedScene

@onready var open_button: Button = $PauseCanvas/EnterImage/OpenButton

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


func _close_shop() -> void:
	_shop_open                 = false
	open_button.button_pressed = false
	open_button.text           = "OFF"
