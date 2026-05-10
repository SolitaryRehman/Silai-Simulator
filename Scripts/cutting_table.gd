# cutting_table.gd
extends Area3D

# grab all the nodes we need upfront
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

# these toggles are hidden now — fabric/color come from the DB per dress part
@onready var dress_img:   TextureRect = $cut_ui/DressImg
@onready var fabric_img:  TextureRect = $cut_ui/FabricImg
@onready var color_img:   TextureRect = $cut_ui/ColorImg
@onready var dress_left:  Button      = $cut_ui/DressImg/Button
@onready var dress_right: Button      = $cut_ui/DressImg/Button2
@onready var fabric_left: Button      = $cut_ui/FabricImg/Button
@onready var fabric_right:Button      = $cut_ui/FabricImg/Button2
@onready var color_left:  Button      = $cut_ui/ColorImg/Button
@onready var color_right: Button      = $cut_ui/ColorImg/Button2

# we save these at startup so we can always tween back to the right spot
var _table_cam_global_pos:  Vector3
var _table_cam_global_rot:  Vector3
var _sewing_cam_global_pos: Vector3
var _sewing_cam_global_rot: Vector3

# same idea for the fabric pieces — needed to reset them between cuts
var _front_piece_init_xform: Transform3D
var _back_piece_init_xform:  Transform3D

# who's standing at the table right now, and whether the cut already happened
var player_ref: CharacterBody3D = null
var _cut_done:  bool            = false

# the order picker panel built entirely in code
var _order_select_layer: CanvasLayer   = null
var _order_select_panel: Panel         = null
var _order_list_vbox:    VBoxContainer = null

# floating labels that show which dress we're on during cutting/sewing
var _dress_progress_label: Label = null
var _dress_info_label:     Label = null


func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited",  _on_body_exited)

	# snapshot starting transforms so we can reset later
	_front_piece_init_xform = front_piece.global_transform
	_back_piece_init_xform  = back_piece.global_transform

	_table_cam_global_pos  = table_camera.global_position
	_table_cam_global_rot  = table_camera.rotation_degrees
	_sewing_cam_global_pos = sewing_camera.global_position
	_sewing_cam_global_rot = sewing_camera.rotation_degrees

	# nothing should be active until the player walks up
	table_camera.current  = false
	sewing_camera.current = false
	front_piece.visible   = false
	back_piece.visible    = false

	# hide the old toggle selectors — not used anymore
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

func _build_dress_progress_labels() -> void:
	# top label — shows "Dress 1 / 3 — T-Shirt" etc.
	_dress_progress_label = Label.new()
	_dress_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dress_progress_label.add_theme_font_size_override("font_size", 22)
	# bright gold so it's readable over anything
	_dress_progress_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	_dress_progress_label.add_theme_constant_override("outline_size", 4)
	_dress_progress_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_dress_progress_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dress_progress_label.position = Vector2(0, 10)
	_dress_progress_label.size     = Vector2(0, 42)
	_dress_progress_label.visible  = false
	cut_ui.add_child(_dress_progress_label)

	# second line — shows fabric and colour info for this dress
	_dress_info_label = Label.new()
	_dress_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dress_info_label.add_theme_font_size_override("font_size", 15)
	_dress_info_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_dress_info_label.add_theme_constant_override("outline_size", 3)
	_dress_info_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_dress_info_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dress_info_label.position = Vector2(0, 46)
	_dress_info_label.size     = Vector2(0, 32)
	_dress_info_label.visible  = false
	cut_ui.add_child(_dress_info_label)


# refresh the progress labels to match whatever dress we're currently on
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
	# sits on layer 8 so it floats above the game but below the cut UI
	_order_select_layer = CanvasLayer.new()
	_order_select_layer.layer = 8
	add_child(_order_select_layer)

	# dim the background so the panel is easy to read
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.60)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_order_select_layer.add_child(overlay)

	# main panel — centered, big enough to show several orders comfortably
	_order_select_panel = Panel.new()
	_order_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	_order_select_panel.custom_minimum_size = Vector2(860, 580)
	_order_select_panel.position            = Vector2(-430, -290)
	_order_select_layer.add_child(_order_select_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 10)
	root_vbox.offset_left   =  18
	root_vbox.offset_top    =  16
	root_vbox.offset_right  = -18
	root_vbox.offset_bottom = -16
	_order_select_panel.add_child(root_vbox)

	# gold title at the top
	var title := Label.new()
	title.text = "✂   SELECT ORDER TO WORK ON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	root_vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	root_vbox.add_child(sep)

	# order rows get added here dynamically when the panel opens
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_order_list_vbox = VBoxContainer.new()
	_order_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_order_list_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_order_list_vbox)

	# close sends the player back to free roam and recaptures the mouse
	var close_btn := Button.new()
	close_btn.text = "✕   Close  (back to roaming)"
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.custom_minimum_size = Vector2(0, 42)
	close_btn.pressed.connect(_close_order_select_and_recapture)
	root_vbox.add_child(close_btn)

	_order_select_layer.visible = false


func _open_order_select_panel() -> void:
	# clear old rows before repopulating
	for child in _order_list_vbox.get_children():
		child.queue_free()

	var rows: Array = Database.get_pending_orders()

	if rows.is_empty():
		var lbl := Label.new()
		lbl.text = "No pending orders right now."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_order_list_vbox.add_child(lbl)
	else:
		for row in rows:
			_order_list_vbox.add_child(_build_order_row(row))

	_order_select_layer.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# player hit Close without picking — put the mouse back in captured mode
func _close_order_select_and_recapture() -> void:
	_order_select_layer.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _build_order_row(row: Dictionary) -> PanelContainer:
	# each order gets a dark card so rows are visually separated
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color         = Color(0.14, 0.16, 0.22, 0.92)
	style.border_color     = Color(0.35, 0.40, 0.60, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	card.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)

	# pick an icon based on customer type
	var ctype: String = row.get("Customer_Type", "Normal")
	var icon:  String = "⭐" if ctype == "VIP" else ("⚠" if ctype == "Rude" else "👤")

	# order number, customer name, and city all on one line
	var id_lbl := Label.new()
	id_lbl.text = "Order #%d   %s %s  —  %s" % [
		row.get("OrderID", 0), icon, row.get("Customer_Name", "?"), row.get("City", "?")
	]
	id_lbl.add_theme_font_size_override("font_size", 19)
	id_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	info_vbox.add_child(id_lbl)

	# how many dresses and what types
	var dress_lbl := Label.new()
	dress_lbl.text = "  %d dress(es):  %s" % [int(row.get("Dress_count", 0)), row.get("Dresses", "—")]
	dress_lbl.add_theme_font_size_override("font_size", 15)
	dress_lbl.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	info_vbox.add_child(dress_lbl)

	# due date in grey so it doesn't compete with the main info
	var date_lbl := Label.new()
	date_lbl.text = "  Due: %s" % row.get("Receiving_date", "?")
	date_lbl.add_theme_font_size_override("font_size", 13)
	date_lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.58))
	info_vbox.add_child(date_lbl)

	hbox.add_child(info_vbox)

	# the actual button to start working on this order
	var btn := Button.new()
	btn.text = "Work on This  →"
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(180, 52)
	var oid: int = int(row.get("OrderID", -1))
	btn.pressed.connect(func(): _on_order_selected(oid))
	hbox.add_child(btn)

	return card


func _on_order_selected(order_id: int) -> void:
	# hide the panel first, then try to activate the order
	_order_select_layer.visible = false

	if not GameManager.set_active_order(order_id):
		push_warning("CuttingTable: Could not activate order %d." % order_id)
		_order_select_layer.visible = true
		return

	_update_dress_progress()
	_start_cutting()


# ── Button dispatcher ─────────────────────────────────────────────────────────

# same button does CUT then flips to NEXT once the cut is done
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
		# no active order — open the picker if there's anything to pick from
		if GameManager.current_order.is_empty():
			if GameManager.pending_orders.is_empty():
				print("CuttingTable: No pending orders.")
				return
			_open_order_select_panel()
			return

		# order already selected and waiting to be cut
		if GameManager.current_order.get("status") == "pending_cut":
			_start_cutting()
		return

	if GameManager.current_state != GameManager.GameState.CUTTING:
		return


# ── Cutting flow ──────────────────────────────────────────────────────────────

func _start_cutting(snap_camera_to_player: bool = true) -> void:
	get_parent().on_cutting_started()
	GameManager.current_state = GameManager.GameState.CUTTING
	# lock the player in place so they can't walk away mid-cut
	player_ref.lock_for_minigame()
	prompt_label.visible = false

	# hide the old toggle selectors — not used anymore
	dress_img.visible  = false
	fabric_img.visible = false
	color_img.visible  = false

	# show the fabric and outlines, hide the already-cut pieces
	fabric_mesh.visible   = true
	front_outline.visible = true
	back_outline.visible  = true
	front_piece.visible   = false
	back_piece.visible    = false

	_update_dress_progress()
	_dress_progress_label.visible = true
	_dress_info_label.visible     = true
	cut_ui.visible = true

	# snap from the player camera or just slide back to the cut position
	if snap_camera_to_player:
		await _switch_to_table_camera()
	else:
		await _return_camera_to_cut_pos()


func _do_cut() -> void:
	_reset_pieces()

	var dress_row: Dictionary = {}
	if not GameManager.order_dresses.is_empty():
		dress_row = GameManager.order_dresses[GameManager.current_dress_index]

	var dress_type:   String = dress_row.get("Dress_type", "T-Shirt")
	var clothing_key: String = dress_type.to_lower().replace(" ", "_")
	if ClothingConfig.get_config(clothing_key).is_empty():
		clothing_key = "tshirt"

	GameManager.current_order["dress"] = dress_type
	GameManager.current_order["type"]  = clothing_key

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

	# Wait one frame so any leftover deferred ops from the sewing machine
	# can't stomp our visibility right after we set it.
	await get_tree().process_frame
	front_piece.visible = true   # reaffirm after the frame
	back_piece.visible  = true

	_animate_cut_split()


func _animate_cut_split() -> void:
	# slide the pieces apart, flip the back one, then bring them back together
	var t1 := create_tween().set_parallel(true)
	t1.tween_property(front_piece, "position:z",         0.18, 0.30).set_ease(Tween.EASE_OUT)
	t1.tween_property(back_piece,  "position:z",        -0.18, 0.30).set_ease(Tween.EASE_OUT)
	t1.tween_property(back_piece,  "rotation_degrees:y", 90.0, 0.45).set_ease(Tween.EASE_IN_OUT)
	await t1.finished
	await get_tree().create_timer(0.95).timeout   # brief pause so the player can see the result
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(front_piece, "position:z", 0.000, 0.25).set_ease(Tween.EASE_IN)
	t2.tween_property(back_piece,  "position:z", 0.002, 0.25).set_ease(Tween.EASE_IN)
	await t2.finished
	_on_cutting_complete()


func _on_cutting_complete() -> void:
	GameManager.complete_cutting()
	# flip the button to NEXT so the player knows to move on to sewing
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

	# tag the pieces so the sewing machine can find them
	front_piece.add_to_group("sewing_pieces")
	back_piece.add_to_group("sewing_pieces")
	_switch_to_sewing_camera()
	await _move_pieces_to_sewing()

	# hand the pieces off to the sewing machine and wait for it to finish
	var sm: Node = get_tree().get_first_node_in_group("sewing_machine")
	if sm == null:
		push_error("CuttingTable: sewing_machine group not found!")
		return
	sm.begin_sewing([front_piece, back_piece], GameManager.current_order.get("type", "tshirt"), table_camera)
	sm.sewing_complete.connect(_on_sewing_complete, CONNECT_ONE_SHOT)


func _on_sewing_complete() -> void:
	_cut_done       = false
	cut_button.text = "CUT"

	front_piece.remove_from_group("sewing_pieces")
	back_piece.remove_from_group("sewing_pieces")

	# If sewing machine took ownership of the pieces, return them here
	# so their parent visibility can never block them during the next cut.
	if front_piece.get_parent() != self:
		front_piece.reparent(self, true)   # true = keep global transform
	if back_piece.get_parent() != self:
		back_piece.reparent(self, true)

	_reset_pieces()
	front_piece.visible = false
	back_piece.visible  = false

	var next: int = GameManager.current_dress_index + 1

	if next < GameManager.order_dresses.size():
		# more dresses to do — loop back to cutting
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
		# all dresses done — release the player and finalize the order
		_dress_progress_label.visible = false
		_dress_info_label.visible     = false
		await _switch_to_player_camera()
		player_ref.unlock_from_minigame()
		prompt_label.visible      = true
		GameManager.current_state = GameManager.GameState.FREE_ROAM
		GameManager.complete_sewing()


# ── Camera helpers ────────────────────────────────────────────────────────────

# snap from wherever the player is standing and smoothly slide to the table view
func _switch_to_table_camera() -> void:
	var pc: Camera3D = player_ref.get_node("Head/Camera3D")
	table_camera.global_position  = pc.global_position
	table_camera.rotation_degrees = pc.rotation_degrees
	table_camera.current = true
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _table_cam_global_pos, 0.5).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _table_cam_global_rot, 0.5).set_ease(Tween.EASE_IN_OUT)
	await t.finished


# used when coming back from sewing — just slide back to the cut position
func _return_camera_to_cut_pos() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _table_cam_global_pos, 0.5).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _table_cam_global_rot, 0.5).set_ease(Tween.EASE_IN_OUT)
	await t.finished


# slide back to the player's head camera when leaving the minigame
func _switch_to_player_camera() -> void:
	var pc: Camera3D = player_ref.get_node("Head/Camera3D")
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  pc.global_position,  0.4).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", pc.rotation_degrees, 0.4).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	pc.current           = true
	table_camera.current = false


# pan over to the sewing machine position before handing off
func _switch_to_sewing_camera() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(table_camera, "global_position",  _sewing_cam_global_pos, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(table_camera, "rotation_degrees", _sewing_cam_global_rot, 0.7).set_ease(Tween.EASE_IN_OUT)
	await t.finished


# fly both pieces over to the sewing machine and rotate them to face the right way
func _move_pieces_to_sewing() -> void:
	var sewing_pos := Vector3(0.66, 1.28, 13.8)
	var fr := front_piece.rotation_degrees; fr.y += 270.0
	var br := back_piece.rotation_degrees;  br.y += 270.0
	var t := create_tween().set_parallel(true)
	t.tween_property(front_piece, "global_position",  sewing_pos, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(back_piece,  "global_position",  sewing_pos, 0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(front_piece, "rotation_degrees", fr,         0.7).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(back_piece,  "rotation_degrees", br,         0.7).set_ease(Tween.EASE_IN_OUT)
	await t.finished


# ── Area detection ────────────────────────────────────────────────────────────

# player walked in — store a reference and show the prompt if there's work to do
func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		player_ref = body
		if not GameManager.current_order.is_empty() or not GameManager.pending_orders.is_empty():
			prompt_label.visible = true


# player walked away — clear the reference and hide the prompt
func _on_body_exited(body) -> void:
	if body.is_in_group("player"):
		player_ref = null
		prompt_label.visible = false


# player cancelled mid-cut — clean everything up and return to free roam
func _on_cutting_cancelled() -> void:
	cut_ui.visible = false
	_dress_progress_label.visible = false
	_dress_info_label.visible     = false
	_cut_done       = false
	cut_button.text = "CUT"
	fabric_mesh.visible   = true
	front_outline.visible = true
	back_outline.visible  = true
	front_piece.visible   = false
	back_piece.visible    = false
	await _switch_to_player_camera()
	player_ref.unlock_from_minigame()
	if player_ref != null:
		prompt_label.visible = true
	GameManager.current_state = GameManager.GameState.FREE_ROAM


# put both pieces back to where they started and hide them
func _reset_pieces() -> void:
	front_piece.global_transform = _front_piece_init_xform
	back_piece.global_transform  = _back_piece_init_xform
	front_piece.visible          = false
	back_piece.visible           = false
