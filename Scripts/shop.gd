extends Node3D

@export var customer_scene_berserker: PackedScene
@export var customer_scene_girl: PackedScene

@onready var open_button: Button = $PauseCanvas/EnterImage/OpenButton

var _shop_open: bool = false
var _spawn_timer: Timer
var _customer_active: bool = false


func _ready() -> void:
	open_button.toggle_mode = true
	open_button.button_pressed = false
	open_button.text = "OFF"
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
		_shop_open = false
		open_button.button_pressed = false
		open_button.text = "OFF"
		return

	if randi() % 2 == 0:
		var customer = customer_scene_berserker.instantiate()
		add_child(customer)
		customer.global_position = Vector3(9.56, 0.0, -1.0)
		customer.scale = Vector3(1.3, 1.3, 1.3)
		customer.customer_left.connect(_on_customer_left)
	else:
		var customer = customer_scene_girl.instantiate()
		add_child(customer)
		customer.global_position = Vector3(9.56, 0.0, -1.0)
		customer.scale = Vector3(1.2, 1.2, 1.2)
		customer.customer_left.connect(_on_customer_left)

	_customer_active = true
	_shop_open = false
	open_button.button_pressed = false
	open_button.text = "OFF"


func _on_customer_left() -> void:
	_customer_active = false
