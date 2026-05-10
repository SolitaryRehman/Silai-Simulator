extends CanvasLayer

@onready var pause_menu: TextureRect   = $TextureRect
@onready var resume_button: Button     = $TextureRect/ResumeButton
@onready var quit_button: Button       = $TextureRect/QuitButton

# remember what the mouse was doing before we paused so we can restore it on resume
var _mouse_mode_before_pause: Input.MouseMode

func _ready():
	# runs even while the tree is paused so the resume button actually works
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_to_main_menu_pressed)

func _unhandled_input(event: InputEvent):
	# only catch Escape if nothing else already consumed it and we're not already paused
	if event.is_action_pressed("ui_cancel"):
		if not get_tree().paused:
			_pause()

func _pause():
	# save current mouse mode so captured/confined cursors get properly restored
	_mouse_mode_before_pause = Input.get_mouse_mode()
	get_tree().paused     = true
	pause_menu.visible    = true
	# always show the cursor in the pause menu regardless of what the game was doing
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume():
	get_tree().paused  = false
	pause_menu.visible = false
	# put the cursor back exactly how the game had it before the player hit Escape
	Input.set_mouse_mode(_mouse_mode_before_pause)

func _on_resume_pressed():
	_resume()

func _on_quit_to_main_menu_pressed() -> void:
	# unpause first — tweens don't tick while the tree is paused
	get_tree().paused = false
	# fade to black before switching so it doesn't hard-cut back to the main menu
	var black_rect = ColorRect.new()
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black_rect)

	var tween = create_tween()
	tween.tween_property(black_rect, "color", Color(0, 0, 0, 1), 1.5)\
		.set_trans(Tween.TRANS_LINEAR)

	await tween.finished
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
