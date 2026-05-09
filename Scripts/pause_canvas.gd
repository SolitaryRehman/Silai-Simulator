#pause_canvas.gd
extends CanvasLayer

@onready var pause_menu: TextureRect   = $TextureRect  
@onready var resume_button: Button     = $TextureRect/ResumeButton
@onready var quit_button: Button = $TextureRect/QuitButton


var _mouse_mode_before_pause: Input.MouseMode

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_to_main_menu_pressed)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if not get_tree().paused:
			_pause()

func _pause():
	_mouse_mode_before_pause = Input.get_mouse_mode()
	get_tree().paused     = true
	pause_menu.visible    = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume():
	get_tree().paused  = false
	pause_menu.visible = false
	Input.set_mouse_mode(_mouse_mode_before_pause)

func _on_resume_pressed():
	_resume()

func _on_quit_to_main_menu_pressed() -> void:
	get_tree().paused = false  # unpause first so tween runs

	var black_rect = ColorRect.new()
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black_rect)

	var tween = create_tween()
	tween.tween_property(black_rect, "color", Color(0, 0, 0, 1), 1.5)\
		.set_trans(Tween.TRANS_LINEAR)

	await tween.finished
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
