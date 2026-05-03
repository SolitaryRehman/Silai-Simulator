extends Area3D


@onready var prompt_label: Label3D       = $PromptLabel
@onready var fabric_mesh: MeshInstance3D = $fabric_plane
@onready var table_camera: Camera3D      = $table_camera
@onready var sewing_camera: Camera3D     = $sewing_camera

@onready var front_piece: MeshInstance3D = $front_piece
@onready var back_piece: MeshInstance3D = $back_piece
@onready var front_outline: Sprite3D     = $front_outline
@onready var back_outline: Sprite3D      = $back_outline

@onready var cut_ui: CanvasLayer         = $cut_ui
@onready var cut_button: Button = $cut_ui/TextureRect/cut_button

@onready var dress_img:  TextureRect = $cut_ui/DressImg
@onready var fabric_img: TextureRect = $cut_ui/FabricImg
@onready var color_img:  TextureRect = $cut_ui/ColorImg

@onready var label_dress:   Label         = $cut_ui/DressImg/Label
@onready var label_fabric:  Label         = $cut_ui/FabricImg/Label
@onready var label_color:   Label         = $cut_ui/ColorImg/Label

@onready var dress_left:    Button        = $cut_ui/DressImg/Button
@onready var dress_right:   Button        = $cut_ui/DressImg/Button2
@onready var fabric_left:   Button        = $cut_ui/FabricImg/Button
@onready var fabric_right:  Button        = $cut_ui/FabricImg/Button2
@onready var color_left:    Button        = $cut_ui/ColorImg/Button
@onready var color_right:   Button        = $cut_ui/ColorImg/Button2


# ── Selector state ────────────────────────────────────────────
var _dress_pool:  Array = ["T-Shirt", "Frock", "Bishop Gown", "Pants", "Jacket", "Maxi", "Lehenga"]
var _fabric_pool: Array = ["Cotton", "Silk", "Linen", "Polyester", "Lawn", "Chiffon", "Denim"]
var _color_pool:  Array = ["Navy Blue", "Crimson Red", "Forest Green", "Pearl White", "Jet Black", "Purple", "Golden", "Sky Blue"]

var _dress_index:  int = 0
var _fabric_index: int = 0
var _color_index:  int = 0

var player_ref: CharacterBody3D = null
var _cut_done: bool = false   # tracks which action the button triggers

var _table_cam_global_pos: Vector3
var _table_cam_global_rot: Vector3

var _sewing_cam_global_pos: Vector3   # save sewing cam target
var _sewing_cam_global_rot: Vector3

var _front_piece_init_rot: Vector3
var _back_piece_init_rot: Vector3

var _front_piece_init_pos: Vector3
var _back_piece_init_pos: Vector3

func _ready():
	
	connect("body_entered", _on_body_entered)
	connect("body_exited",  _on_body_exited)
	
	_front_piece_init_rot = front_piece.rotation_degrees
	_back_piece_init_rot  = back_piece.rotation_degrees
	
	_front_piece_init_pos = front_piece.position
	_back_piece_init_pos  = back_piece.position
	
	# Save BEFORE anything moves the camera
	_table_cam_global_pos = table_camera.global_position
	_table_cam_global_rot = table_camera.rotation_degrees
	
	_sewing_cam_global_pos = sewing_camera.global_position   # ← save before anything moves
	_sewing_cam_global_rot = sewing_camera.rotation_degrees


	table_camera.current = false
	sewing_camera.current  = false

	front_piece.visible  = false
	back_piece.visible   = false
	
	# ── Connect selector buttons ──────────────────────────────
	dress_left.pressed.connect(_on_dress_left)
	dress_right.pressed.connect(_on_dress_right)
	fabric_left.pressed.connect(_on_fabric_left)
	fabric_right.pressed.connect(_on_fabric_right)
	color_left.pressed.connect(_on_color_left)
	color_right.pressed.connect(_on_color_right)

	# ── Set initial label text ────────────────────────────────
	label_dress.text  = _dress_pool[0]
	label_fabric.text = _fabric_pool[0]
	label_color.text  = _color_pool[0]
	
	# Hide UI until cutting starts
	cut_ui.visible = false

	cut_button.pressed.connect(_on_cut_button_pressed)   # ← single handler, branches by state
	cut_button.text = "CUT"
	
	print("CuttingTable ready!")


# ── Arrow callbacks ───────────────────────────────────────────
func _on_dress_left() -> void:
	_dress_index = (_dress_index - 1 + _dress_pool.size()) % _dress_pool.size()
	label_dress.text = _dress_pool[_dress_index]

func _on_dress_right() -> void:
	_dress_index = (_dress_index + 1) % _dress_pool.size()
	label_dress.text = _dress_pool[_dress_index]

func _on_fabric_left() -> void:
	_fabric_index = (_fabric_index - 1 + _fabric_pool.size()) % _fabric_pool.size()
	label_fabric.text = _fabric_pool[_fabric_index]

func _on_fabric_right() -> void:
	_fabric_index = (_fabric_index + 1) % _fabric_pool.size()
	label_fabric.text = _fabric_pool[_fabric_index]

func _on_color_left() -> void:
	_color_index = (_color_index - 1 + _color_pool.size()) % _color_pool.size()
	label_color.text = _color_pool[_color_index]

func _on_color_right() -> void:
	_color_index = (_color_index + 1) % _color_pool.size()
	label_color.text = _color_pool[_color_index]


# ── Button press dispatcher ────────────────────────────────────
func _on_cut_button_pressed():
	if _cut_done:
		_go_to_sewing()
	else:
		_do_cut()


func _process(_delta):
	if player_ref == null:
		return

	if Input.is_action_just_pressed("interact"):
		print("E pressed!")
		print("Order: ",  GameManager.current_order)
		print("Status: ", GameManager.current_order.get("status"))

		if GameManager.current_order.is_empty():
			print("No active order!")
			return
		if GameManager.current_order.get("status") == "pending_cut":
			_start_cutting()
		return

	if GameManager.current_state != GameManager.GameState.CUTTING:
		return


func _start_cutting():
	GameManager.current_state = GameManager.GameState.CUTTING
	player_ref.lock_for_minigame()
	prompt_label.visible = false
	
	dress_img.visible  = true 
	fabric_img.visible = true  
	color_img.visible  = true
	
	fabric_mesh.visible   = true
	
	front_outline.visible = true
	back_outline.visible  = true
	front_piece.visible   = false
	back_piece.visible    = false

	cut_ui.visible = true    # show the cut button

	await _switch_to_table_camera()


func _do_cut():
	
	_reset_pieces()
	
	GameManager.current_order["dress"]  = _dress_pool[_dress_index]
	GameManager.current_order["fabric"] = _fabric_pool[_fabric_index]
	GameManager.current_order["color"]  = _color_pool[_color_index]
	GameManager.current_order["type"]   = _dress_pool[_dress_index].to_lower().replace(" ", "_")
	
	dress_img.visible  = false   
	fabric_img.visible = false   
	color_img.visible  = false
	
	cut_ui.visible = false

	fabric_mesh.visible   = false
	front_outline.visible = false
	back_outline.visible  = false

	var center: Vector3         = fabric_mesh.global_position
	front_piece.global_position = center
	back_piece.global_position  = center
	back_piece.position.z      += 0.002

	front_piece.visible = true
	back_piece.visible  = true

	_animate_cut_split()


func _animate_cut_split():
	var t1 := create_tween().set_parallel(true)
	t1.tween_property(front_piece, "position:z",  0.18, 0.30).set_ease(Tween.EASE_OUT)
	t1.tween_property(back_piece,  "position:z", -0.18, 0.30).set_ease(Tween.EASE_OUT)
	t1.tween_property(back_piece,  "rotation_degrees:y",  90.0, 0.45).set_ease(Tween.EASE_IN_OUT)
	await t1.finished

	await get_tree().create_timer(0.95).timeout

	var t2 := create_tween().set_parallel(true)
	t2.tween_property(front_piece, "position:z",  0.000, 0.25).set_ease(Tween.EASE_IN)
	t2.tween_property(back_piece,  "position:z",  0.002, 0.25).set_ease(Tween.EASE_IN)
	await t2.finished

	_on_cutting_complete()


func _on_cutting_complete():
	GameManager.complete_cutting()

	# ── Show "Next" button instead of returning to player ──────
	_cut_done = true
	cut_button.text = "NEXT →"
	cut_ui.visible  = true


# ── Move to sewing station ─────────────────────────────────────

func _go_to_sewing() -> void:
	cut_ui.visible = false

	# Add pieces to a group so SewingMachine can find+shrink them
	front_piece.add_to_group("sewing_pieces")
	back_piece.add_to_group("sewing_pieces")

	# Animate pieces to sewing station AND move camera simultaneously
	_switch_to_sewing_camera()           # no await — fires in parallel
	await _move_pieces_to_sewing()       # wait for pieces to arrive

	# Hand off to the sewing machine
	var sewing_machine: Node = get_tree().get_first_node_in_group("sewing_machine")
	if sewing_machine == null:
		push_error("CuttingTable: no node in group 'sewing_machine' found!")
		return

	var clothing_type: String = GameManager.current_order.get("type", "shirt")
	sewing_machine.begin_sewing([front_piece, back_piece], clothing_type, table_camera)
	sewing_machine.sewing_complete.connect(_on_sewing_complete, CONNECT_ONE_SHOT)


func _on_sewing_complete() -> void:
	_cut_done = false
	cut_button.text = "CUT"

	front_piece.remove_from_group("sewing_pieces")
	back_piece.remove_from_group("sewing_pieces")
	
	_reset_pieces()
	
	front_piece.visible = false   # ← keep hidden
	back_piece.visible  = false   # ← keep hidden

	await _switch_to_player_camera()
	player_ref.unlock_from_minigame()
	prompt_label.visible = true
	GameManager.current_state = GameManager.GameState.FREE_ROAM
	GameManager.complete_sewing()

func _switch_to_sewing_camera():
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _sewing_cam_global_pos, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _sewing_cam_global_rot, 0.7).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _move_pieces_to_sewing():
	var sewing_pos := Vector3(0.66, 1.28, 13.8)

	var front_target_rot := front_piece.rotation_degrees
	front_target_rot.y   += 270.0
	var back_target_rot  := back_piece.rotation_degrees
	back_target_rot.y    += 270.0

	var t := create_tween().set_parallel(true)
	t.tween_property(front_piece, "global_position",  sewing_pos,       0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(back_piece,  "global_position",  sewing_pos,       0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(front_piece, "rotation_degrees", front_target_rot, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(back_piece,  "rotation_degrees", back_target_rot,  0.7).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _on_cutting_cancelled():
	cut_ui.visible = false   # hide button on cancel 
	
	_cut_done = false                      # ← reset state for next visit
	cut_button.text = "✂   CUT FABRIC"    # ← restore original label
	
	await _switch_to_player_camera()
	player_ref.unlock_from_minigame()
	if player_ref != null:
		prompt_label.visible = true
	front_piece.visible   = false
	back_piece.visible    = false
	fabric_mesh.visible   = true
	front_outline.visible = true
	back_outline.visible  = true
	GameManager.current_state = GameManager.GameState.FREE_ROAM


# ── Camera switching ───────────────────────────────────────────

func _switch_to_table_camera():
	var player_cam: Camera3D = player_ref.get_node("Head/Camera3D")

	table_camera.global_position  = player_cam.global_position
	table_camera.rotation_degrees = player_cam.rotation_degrees
	table_camera.current = true

	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _table_cam_global_pos, 0.5).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _table_cam_global_rot, 0.5).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _switch_to_player_camera():
	var player_cam: Camera3D = player_ref.get_node("Head/Camera3D")

	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  player_cam.global_position,  0.4).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", player_cam.rotation_degrees, 0.4).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	player_cam.current   = true
	table_camera.current = false


# ── Area detection ─────────────────────────────────────────────

func _on_body_entered(body):
	print("Something entered: ", body.name)
	print("Is in player group: ", body.is_in_group("player"))

	if body.is_in_group("player"):
		player_ref = body
		if not GameManager.current_order.is_empty():
			prompt_label.visible = true


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_ref = null
		prompt_label.visible = false


func _reset_pieces() -> void:
	front_piece.rotation_degrees = _front_piece_init_rot
	back_piece.rotation_degrees  = _back_piece_init_rot
	front_piece.position         = _front_piece_init_pos
	back_piece.position          = _back_piece_init_pos
	front_piece.scale            = Vector3.ONE
	back_piece.scale             = Vector3.ONE
	front_piece.visible          = false
	back_piece.visible           = false
