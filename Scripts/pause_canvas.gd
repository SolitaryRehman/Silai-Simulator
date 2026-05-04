extends CanvasLayer

@onready var pause_menu: TextureRect = $TextureRect  
@onready var resume_button: Button   = $TextureRect/ResumeButton

var _mouse_mode_before_pause: Input.MouseMode  # ← add this

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	resume_button.pressed.connect(_on_resume_pressed)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume()
		else:
			_pause()

func _pause():
	_mouse_mode_before_pause = Input.get_mouse_mode()  # ← save it
	get_tree().paused     = true
	pause_menu.visible    = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume():
	get_tree().paused  = false
	pause_menu.visible = false
	Input.set_mouse_mode(_mouse_mode_before_pause)  # ← restore exactly what it was

func _on_resume_pressed():
	_resume()
