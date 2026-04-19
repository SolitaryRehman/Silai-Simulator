extends Area3D


@onready var prompt_label: Label3D       = $PromptLabel
@onready var fabric_mesh: MeshInstance3D = $fabric_plane
@onready var table_camera: Camera3D      = $table_camera
@onready var sewing_camera: Camera3D     = $sewing_camera
@onready var front_piece: MeshInstance3D = $front_piece
@onready var back_piece: MeshInstance3D  = $back_piece
@onready var front_outline: Sprite3D     = $front_outline
@onready var back_outline: Sprite3D      = $back_outline
@onready var cut_ui: CanvasLayer         = $cut_ui
@onready var cut_button: Button          = $cut_ui/cut_button

var player_ref: CharacterBody3D = null
var _cut_done: bool = false   # tracks which action the button triggers

var _table_cam_global_pos: Vector3
var _table_cam_global_rot: Vector3

var _sewing_cam_global_pos: Vector3   # save sewing cam target
var _sewing_cam_global_rot: Vector3

func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited",  _on_body_exited)

	# Save BEFORE anything moves the camera
	_table_cam_global_pos = table_camera.global_position
	_table_cam_global_rot = table_camera.rotation_degrees
	
	_sewing_cam_global_pos = sewing_camera.global_position   # ← save before anything moves
	_sewing_cam_global_rot = sewing_camera.rotation_degrees


	table_camera.current = false
	sewing_camera.current  = false

	front_piece.visible  = false
	back_piece.visible   = false

	# Create the button in code and add it to the CanvasLayer
	cut_button = Button.new()
	cut_ui.add_child(cut_button)

	_setup_cut_button()

	# Hide UI until cutting starts
	cut_ui.visible = false

	cut_button.pressed.connect(_on_cut_button_pressed)   # ← single handler, branches by state

	print("CuttingTable ready!")


# ── Button press dispatcher ────────────────────────────────────

func _on_cut_button_pressed():
	if _cut_done:
		_go_to_sewing()
	else:
		_do_cut()


func _setup_cut_button():
	# ── Position: mid-right ───────────────────────────────────
	cut_button.anchor_left   = 1.0
	cut_button.anchor_right  = 1.0
	cut_button.anchor_top    = 0.5
	cut_button.anchor_bottom = 0.5
	cut_button.offset_left   = -220.0
	cut_button.offset_right  = -20.0
	cut_button.offset_top    = -40.0
	cut_button.offset_bottom = 40.0

	cut_button.text = "✂   CUT FABRIC"

	# ── Font size ─────────────────────────────────────────────
	cut_button.add_theme_font_size_override("font_size", 17)

	# ── Normal state — dark charcoal with gold border ─────────
	var normal := StyleBoxFlat.new()
	normal.bg_color             = Color(0.10, 0.09, 0.08, 0.95)
	normal.border_color         = Color(0.85, 0.68, 0.30, 1.0)   # gold
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(14)
	normal.shadow_color         = Color(0.85, 0.68, 0.30, 0.25)
	normal.shadow_size          = 8
	cut_button.add_theme_stylebox_override("normal", normal)

	# ── Hover state — gold tint ───────────────────────────────
	var hover := StyleBoxFlat.new()
	hover.bg_color              = Color(0.85, 0.68, 0.30, 0.18)
	hover.border_color          = Color(0.95, 0.80, 0.40, 1.0)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(14)
	hover.shadow_color          = Color(0.85, 0.68, 0.30, 0.45)
	hover.shadow_size           = 12
	cut_button.add_theme_stylebox_override("hover", hover)

	# ── Pressed state — bright gold flash ────────────────────
	var pressed := StyleBoxFlat.new()
	pressed.bg_color            = Color(0.85, 0.68, 0.30, 0.35)
	pressed.border_color        = Color(1.0, 0.92, 0.55, 1.0)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(14)
	cut_button.add_theme_stylebox_override("pressed", pressed)

	# ── Text colours ──────────────────────────────────────────
	cut_button.add_theme_color_override("font_color",         Color(0.90, 0.75, 0.35, 1.0))
	cut_button.add_theme_color_override("font_hover_color",   Color(1.00, 0.90, 0.50, 1.0))
	cut_button.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 0.70, 1.0))



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

	if Input.is_action_just_pressed("ui_cancel"):
		_on_cutting_cancelled()


func _start_cutting():
	GameManager.current_state = GameManager.GameState.CUTTING
	player_ref.lock_for_minigame()
	prompt_label.visible = false

	fabric_mesh.visible   = true
	front_outline.visible = true
	back_outline.visible  = true
	front_piece.visible   = false
	back_piece.visible    = false

	cut_ui.visible = true    # show the cut button

	await _switch_to_table_camera()


func _do_cut():
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

	await get_tree().create_timer(0.65).timeout

	var t2 := create_tween().set_parallel(true)
	t2.tween_property(front_piece, "position:z",  0.000, 0.25).set_ease(Tween.EASE_IN)
	t2.tween_property(back_piece,  "position:z",  0.002, 0.25).set_ease(Tween.EASE_IN)
	await t2.finished

	_on_cutting_complete()


func _on_cutting_complete():
	GameManager.complete_cutting()

	# ── Show "Next" button instead of returning to player ──────
	_cut_done = true
	cut_button.text = "→   NEXT"
	cut_ui.visible  = true


# ── Move to sewing station ─────────────────────────────────────

func _go_to_sewing():
	cut_ui.visible = false
	await _switch_to_sewing_camera()


func _switch_to_sewing_camera():
	# Tween the active table_camera to the sewing camera's saved world position
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _sewing_cam_global_pos, 0.6).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _sewing_cam_global_rot, 0.6).set_ease(Tween.EASE_IN_OUT)
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
