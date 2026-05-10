# cutting_table.gd
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
@onready var cut_button: Button          = $cut_ui/TextureRect/cut_button

# CHANGE 6: Toggle selector panels hidden — per-part fabric/color comes from DB
@onready var dress_img:   TextureRect = $cut_ui/DressImg
@onready var fabric_img:  TextureRect = $cut_ui/FabricImg
@onready var color_img:   TextureRect = $cut_ui/ColorImg
@onready var dress_left:  Button      = $cut_ui/DressImg/Button
@onready var dress_right: Button      = $cut_ui/DressImg/Button2
@onready var fabric_left: Button      = $cut_ui/FabricImg/Button
@onready var fabric_right:Button      = $cut_ui/FabricImg/Button2
@onready var color_left:  Button      = $cut_ui/ColorImg/Button
@onready var color_right: Button      = $cut_ui/ColorImg/Button2

# ── Saved transforms ──────────────────────────────────────────────────────────
var _table_cam_global_pos:  Vector3
var _table_cam_global_rot:  Vector3
var _sewing_cam_global_pos: Vector3
var _sewing_cam_global_rot: Vector3

var _front_piece_init_rot: Vector3
var _back_piece_init_rot:  Vector3
var _front_piece_init_pos: Vector3
var _back_piece_init_pos:  Vector3

# ── Runtime ───────────────────────────────────────────────────────────────────
var player_ref: CharacterBody3D = null
var _cut_done:  bool            = false

# ── Order-selection panel (programmatic) ─────────────────────────────────────
var _order_select_layer: CanvasLayer   = null
var _order_select_panel: Panel         = null
var _order_list_vbox:    VBoxContainer = null

# ── Dress-progress labels inside cut_ui ──────────────────────────────────────
var _dress_progress_label: Label = null
var _dress_info_label:     Label = null


func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited",  _on_body_exited)

	_front_piece_init_rot = front_piece.rotation_degrees
	_back_piece_init_rot  = back_piece.rotation_degrees
	_front_piece_init_pos = front_piece.position
	_back_piece_init_pos  = back_piece.position

	_table_cam_global_pos  = table_camera.global_position
	_table_cam_global_rot  = table_camera.rotation_degrees
	_sewing_cam_global_pos = sewing_camera.global_position
	_sewing_cam_global_rot = sewing_camera.rotation_degrees

	table_camera.current  = false
	sewing_camera.current = false
	front_piece.visible   = false
	back_piece.visible    = false

	# CHANGE 6: Hide toggle selectors — dress/fabric/color chosen per-part by DB
	dress_img.visible  = false
	fabric_img.visible = false
	color_img.visible  = false

	cut_ui.visible = false
	cut_button.pressed.connect(_on_cut_button_pressed)
	cut_button.text = "CUT"

	_build_dress_progress_labels()
	_build_order_select_panel()
	print("CuttingTable ready!")


# ── Dress progress labels ─────────────────────────────────────────────────────
# FIX: increased font sizes, bright colours, and black outline so the labels
# are readable over any background in the cut/sew UI.
func _build_dress_progress_labels() -> void:
	_dress_progress_label = Label.new()
	_dress_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dress_progress_label.add_theme_font_size_override("font_size", 22)
	# Bright gold — clearly visible over dark and light backgrounds
	_dress_progress_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	# Black outline so it pops against any background
	_dress_progress_label.add_theme_constant_override("outline_size", 4)
	_dress_progress_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_dress_progress_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dress_progress_label.position = Vector2(0, 10)
	_dress_progress_label.size     = Vector2(0, 42)
	_dress_progress_label.visible  = false
	cut_ui.add_child(_dress_progress_label)

	_dress_info_label = Label.new()
	_dress_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dress_info_label.add_theme_font_size_override("font_size", 15)
	# Pure white with outline — much more readable than the previous pale blue
	_dress_info_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_dress_info_label.add_theme_constant_override("outline_size", 3)
	_dress_info_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_dress_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dress_info_label.position = Vector2(0, 46)
	_dress_info_label.size     = Vector2(0, 32)
	_dress_info_label.visible  = false
	cut_ui.add_child(_dress_info_label)


func _update_dress_progress() -> void:
	if GameManager.order_dresses.is_empty():
		_dress_progress_label.visible = false
		_dress_info_label.visible     = false
		return
	var idx:   int        = GameManager.current_dress_index
	var total: int        = GameManager.order_dresses.size()
	var row:   Dictionary = GameManager.order_dresses[idx]
	_dress_progress_label.text    = "Dress %d / %d  —  %s" % [idx + 1, total, row.get("Dress_type","Dress")]
	_dress_info_label.text        = "Fabrics: %s     Colors: %s" % [row.get("Fabrics","—"), row.get("Colors","—")]
	_dress_progress_label.visible = true
	_dress_info_label.visible     = true


# ── Order-selection panel ─────────────────────────────────────────────────────
func _build_order_select_panel() -> void:
	_order_select_layer = CanvasLayer.new()
	_order_select_layer.layer = 8
	add_child(_order_select_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_order_select_layer.add_child(overlay)

	_order_select_panel = Panel.new()
	_order_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	_order_select_panel.custom_minimum_size = Vector2(640, 420)
	_order_select_panel.position = Vector2(-320, -210)
	_order_select_layer.add_child(_order_select_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	root_vbox.offset_left   =  12
	root_vbox.offset_top    =  12
	root_vbox.offset_right  = -12
	root_vbox.offset_bottom = -12
	_order_select_panel.add_child(root_vbox)

	var title := Label.new()
	title.text = "✂  SELECT ORDER TO WORK ON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	root_vbox.add_child(title)
	root_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_order_list_vbox = VBoxContainer.new()
	_order_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_order_list_vbox)

	var close_btn := Button.new()
	close_btn.text = "✕  Close (back to roaming)"
	# This close path means player is going back to free roam — re-capture mouse
	close_btn.pressed.connect(_close_order_select_and_recapture)
	root_vbox.add_child(close_btn)

	_order_select_layer.visible = false


func _open_order_select_panel() -> void:
	for child in _order_list_vbox.get_children():
		child.queue_free()

	# Database.get_pending_orders() → SELECT orders WHERE Order_status = 'Pending'
	var rows: Array = Database.get_pending_orders()

	if rows.is_empty():
		var lbl := Label.new()
		lbl.text = "No pending orders right now."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_order_list_vbox.add_child(lbl)
	else:
		for row in rows:
			_order_list_vbox.add_child(_build_order_row(row))

	_order_select_layer.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## Player pressed Close without selecting — going back to free roam, recapture mouse.
func _close_order_select_and_recapture() -> void:
	_order_select_layer.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _build_order_row(row: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var ctype: String = row.get("Customer_Type","Normal")
	var icon:  String = "⭐" if ctype == "VIP" else ("⚠" if ctype == "Rude" else "👤")

	var id_lbl := Label.new()
	id_lbl.text = "Order #%d  %s %s  —  %s" % [
		row.get("OrderID",0), icon, row.get("Customer_Name","?"), row.get("City","?")
	]
	id_lbl.add_theme_font_size_override("font_size", 15)
	info_vbox.add_child(id_lbl)

	var dress_lbl := Label.new()
	dress_lbl.text = "  %d dress(es): %s" % [int(row.get("Dress_count",0)), row.get("Dresses","—")]
	dress_lbl.add_theme_font_size_override("font_size", 12)
	dress_lbl.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
	info_vbox.add_child(dress_lbl)

	var date_lbl := Label.new()
	date_lbl.text = "  Due: %s" % row.get("Receiving_date","?")
	date_lbl.add_theme_font_size_override("font_size", 11)
	date_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_vbox.add_child(date_lbl)

	hbox.add_child(info_vbox)

	var btn := Button.new()
	btn.text = "Work on This →"
	btn.custom_minimum_size = Vector2(140, 0)
	var oid: int = int(row.get("OrderID",-1))
	btn.pressed.connect(func(): _on_order_selected(oid))
	hbox.add_child(btn)
	return hbox


func _on_order_selected(order_id: int) -> void:
	# ── CURSOR FIX ────────────────────────────────────────────────────────────
	# ONLY hide the overlay — do NOT call set_mouse_mode(CAPTURED) here.
	# _start_cutting() calls lock_for_minigame() which calls release_mouse()
	# keeping the mouse VISIBLE so the player can click CUT and drag to sew.
	_order_select_layer.visible = false

	# GameManager.set_active_order() → Database.get_dresses_for_order() to load
	# the dress list into GameManager.order_dresses and reset current_dress_index
	if not GameManager.set_active_order(order_id):
		push_warning("CuttingTable: Could not activate order %d." % order_id)
		_order_select_layer.visible = true
		return

	_update_dress_progress()
	_start_cutting()   # → lock_for_minigame() → release_mouse() → stays VISIBLE ✓


# ── Button dispatcher ─────────────────────────────────────────────────────────
func _on_cut_button_pressed() -> void:
	if _cut_done:
		_go_to_sewing()
	else:
		_do_cut()


# ── Main interaction ──────────────────────────────────────────────────────────
func _process(_delta) -> void:
	if player_ref == null:
		return

	if Input.is_action_just_pressed("interact"):
		if GameManager.current_order.is_empty():
			if GameManager.pending_orders.is_empty():
				print("CuttingTable: No pending orders.")
				return
			_open_order_select_panel()
			return

		if GameManager.current_order.get("status") == "pending_cut":
			_start_cutting()
		return

	if GameManager.current_state != GameManager.GameState.CUTTING:
		return


# ── Cutting flow ──────────────────────────────────────────────────────────────
func _start_cutting(snap_camera_to_player: bool = true) -> void:
	get_parent().on_cutting_started()
	GameManager.current_state = GameManager.GameState.CUTTING
	player_ref.lock_for_minigame()   # → release_mouse() → MOUSE_MODE_VISIBLE ✓
	prompt_label.visible = false

	dress_img.visible  = false
	fabric_img.visible = false
	color_img.visible  = false

	fabric_mesh.visible   = true
	front_outline.visible = true
	back_outline.visible  = true
	front_piece.visible   = false
	back_piece.visible    = false

	_update_dress_progress()
	_dress_progress_label.visible = true
	_dress_info_label.visible     = true
	cut_ui.visible = true

	if snap_camera_to_player:
		await _switch_to_table_camera()
	else:
		await _return_camera_to_cut_pos()


func _do_cut() -> void:
	_reset_pieces()

	# CHANGE 2+6: Dress info from DB via GameManager — no toggle buttons
	var dress_row: Dictionary = {}
	if not GameManager.order_dresses.is_empty():
		dress_row = GameManager.order_dresses[GameManager.current_dress_index]

	var dress_type:   String = dress_row.get("Dress_type","T-Shirt")
	var clothing_key: String = dress_type.to_lower().replace(" ","_")
	if ClothingConfig.get_config(clothing_key).is_empty():
		clothing_key = "tshirt"

	GameManager.current_order["dress"] = dress_type
	GameManager.current_order["type"]  = clothing_key
	# CHANGE 1: order stays 'Pending' in DB — no intermediate status update

	_dress_progress_label.visible = true
	_dress_info_label.visible     = true
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


func _animate_cut_split() -> void:
	var t1 := create_tween().set_parallel(true)
	t1.tween_property(front_piece, "position:z",         0.18, 0.30).set_ease(Tween.EASE_OUT)
	t1.tween_property(back_piece,  "position:z",        -0.18, 0.30).set_ease(Tween.EASE_OUT)
	t1.tween_property(back_piece,  "rotation_degrees:y", 90.0, 0.45).set_ease(Tween.EASE_IN_OUT)
	await t1.finished
	await get_tree().create_timer(0.95).timeout
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(front_piece, "position:z", 0.000, 0.25).set_ease(Tween.EASE_IN)
	t2.tween_property(back_piece,  "position:z", 0.002, 0.25).set_ease(Tween.EASE_IN)
	await t2.finished
	_on_cutting_complete()


func _on_cutting_complete() -> void:
	GameManager.complete_cutting()   # CHANGE 1: no DB status written
	_cut_done       = true
	cut_button.text = "NEXT"
	cut_ui.visible  = true
	_dress_progress_label.visible = true
	_dress_info_label.visible     = true


# ── Sewing handoff ────────────────────────────────────────────────────────────
func _go_to_sewing() -> void:
	cut_ui.visible                = false
	_dress_progress_label.visible = false
	_dress_info_label.visible     = false

	front_piece.add_to_group("sewing_pieces")
	back_piece.add_to_group("sewing_pieces")
	_switch_to_sewing_camera()
	await _move_pieces_to_sewing()

	var sm: Node = get_tree().get_first_node_in_group("sewing_machine")
	if sm == null:
		push_error("CuttingTable: sewing_machine group not found!")
		return
	sm.begin_sewing([front_piece, back_piece], GameManager.current_order.get("type","tshirt"), table_camera)
	sm.sewing_complete.connect(_on_sewing_complete, CONNECT_ONE_SHOT)


# ── CHANGE 2: loop per dress or finalize ──────────────────────────────────────
func _on_sewing_complete() -> void:
	_cut_done       = false
	cut_button.text = "CUT"

	front_piece.remove_from_group("sewing_pieces")
	back_piece.remove_from_group("sewing_pieces")
	_reset_pieces()
	front_piece.visible = false
	back_piece.visible  = false

	var next: int = GameManager.current_dress_index + 1

	if next < GameManager.order_dresses.size():
		GameManager.current_dress_index = next
		print("CuttingTable: dress %d done → starting %d/%d"
			  % [next, next + 1, GameManager.order_dresses.size()])
		await _return_camera_to_cut_pos()
		_update_dress_progress()
		fabric_mesh.visible   = true
		front_outline.visible = true
		back_outline.visible  = true
		_dress_progress_label.visible = true
		_dress_info_label.visible     = true
		cut_ui.visible = true
		GameManager.current_order["status"] = "pending_cut"
	else:
		_dress_progress_label.visible = false
		_dress_info_label.visible     = false
		await _switch_to_player_camera()
		player_ref.unlock_from_minigame()
		prompt_label.visible      = true
		GameManager.current_state = GameManager.GameState.FREE_ROAM
		# CHANGE 1: Pending → Completed directly via finalize_order()
		GameManager.complete_sewing()


# ── Camera helpers ────────────────────────────────────────────────────────────
func _switch_to_table_camera() -> void:
	var pc: Camera3D = player_ref.get_node("Head/Camera3D")
	table_camera.global_position  = pc.global_position
	table_camera.rotation_degrees = pc.rotation_degrees
	table_camera.current = true
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _table_cam_global_pos, 0.5).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _table_cam_global_rot, 0.5).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _return_camera_to_cut_pos() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _table_cam_global_pos, 0.5).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _table_cam_global_rot, 0.5).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _switch_to_player_camera() -> void:
	var pc: Camera3D = player_ref.get_node("Head/Camera3D")
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  pc.global_position,  0.4).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", pc.rotation_degrees, 0.4).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	pc.current           = true
	table_camera.current = false


func _switch_to_sewing_camera() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _sewing_cam_global_pos, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _sewing_cam_global_rot, 0.7).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _move_pieces_to_sewing() -> void:
	var sewing_pos   := Vector3(0.66, 1.28, 13.8)
	var fr := front_piece.rotation_degrees; fr.y += 270.0
	var br := back_piece.rotation_degrees;  br.y += 270.0
	var t := create_tween().set_parallel(true)
	t.tween_property(front_piece, "global_position",  sewing_pos, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(back_piece,  "global_position",  sewing_pos, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(front_piece, "rotation_degrees", fr,         0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(back_piece,  "rotation_degrees", br,         0.7).set_ease(Tween.EASE_IN_OUT)
	await t.finished


# ── Area detection ────────────────────────────────────────────────────────────
func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		player_ref = body
		if not GameManager.current_order.is_empty() or not GameManager.pending_orders.is_empty():
			prompt_label.visible = true


func _on_body_exited(body) -> void:
	if body.is_in_group("player"):
		player_ref = null
		prompt_label.visible = false


func _on_cutting_cancelled() -> void:
	cut_ui.visible = false
	_dress_progress_label.visible = false
	_dress_info_label.visible = false
	_cut_done = false
	cut_button.text = "CUT"
	fabric_mesh.visible = true
	front_outline.visible = true
	back_outline.visible = true
	front_piece.visible = false
	back_piece.visible = false
	await _switch_to_player_camera()
	player_ref.unlock_from_minigame()
	if player_ref != null:
		prompt_label.visible = true
	GameManager.current_state = GameManager.GameState.FREE_ROAM


func _reset_pieces() -> void:
	front_piece.rotation_degrees = _front_piece_init_rot
	back_piece.rotation_degrees  = _back_piece_init_rot
	front_piece.position         = _front_piece_init_pos
	back_piece.position          = _back_piece_init_pos
	front_piece.scale            = Vector3.ONE
	back_piece.scale             = Vector3.ONE
	front_piece.visible          = false
	back_piece.visible           = false
