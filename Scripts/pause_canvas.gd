extends CanvasLayer

@onready var pause_menu: TextureRect = $TextureRect  
@onready var resume_button: Button   = $TextureRect/ResumeButton

func _ready():
	process_mode   = Node.PROCESS_MODE_ALWAYS   # must run while paused
	pause_menu.visible = false
	resume_button.pressed.connect(_on_resume_pressed)

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume()
		else:
			_pause()

func _pause():
	get_tree().paused      = true
	pause_menu.visible     = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume():
	get_tree().paused      = false
	pause_menu.visible     = false
	# Only re-capture mouse if player is NOT in a minigame
	var player = get_tree().get_first_node_in_group("player")
	if player and not player.in_minigame:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed():
	_resume()
