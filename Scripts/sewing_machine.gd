#sewingmachine.gd
extends Node3D

signal sewing_complete

# ── Scene refs ────────────────────────────────────────────────
@onready var needle_tip:     Node3D      = $needle_tip
@onready var sew_ui:         CanvasLayer = $sew_ui
@onready var progress_bar:   ProgressBar = $sew_ui/progress_bar
@onready var status_label:   Label       = $sew_ui/status_label
@onready var hint_label:     Label       = $sew_ui/hint_label
@onready var finished_model: Node3D      = $finished_model
@onready var texture_rect: TextureRect = $sew_ui/TextureRect
@onready var _store_button: Button = $sew_ui/TextureRect/store_button



# ── Runtime state ─────────────────────────────────────────────
var _pieces:        Array      = []
var _config:        Dictionary = {}
var _active_camera: Camera3D   = null

# Drag
var _dragging:             MeshInstance3D = null
var _drag_plane:           Plane
var _drag_offset:          Vector3
var _drag_offset_secondary: Vector3

# Seam tracking — driven by Marker3D children on the pieces
var _seam_markers:    Array[Marker3D] = []
var _seam_done:       Array[bool]     = []
var _seams_completed: int             = 0

# Highlight flash material
var _flash_mat: StandardMaterial3D


func _ready() -> void:
	sew_ui.visible = false
	if finished_model:
		finished_model.visible = false
	_store_button.text = "STORE"
	_store_button.visible = false
	_store_button.pressed.connect(_on_store_pressed)
	texture_rect.visible = false  # hidden until sewing is complete
	_build_flash_material()

# ─────────────────────────────────────────────────────────────
# Called by CuttingTable after pieces arrive at sewing station
# ─────────────────────────────────────────────────────────────
func begin_sewing(pieces: Array, clothing_type: String, camera: Camera3D) -> void:
	_pieces          = pieces
	_config          = ClothingConfig.get_config(clothing_type)
	_active_camera   = camera
	_seams_completed = 0
	_seam_markers.clear()
	_seam_done.clear()

	# ← Reset pieces so they're visible and full-size on every round
	for piece in _pieces:
		piece.visible = true
		piece.scale   = Vector3.ONE

	for piece in _pieces:
		for child in piece.get_children():
			if child is Marker3D and child.is_in_group("seam_point"):
				_seam_markers.append(child)
				_seam_done.append(false)

	_refresh_ui()
	sew_ui.visible  = true
	hint_label.text = "Drag pieces — guide each seam edge to the needle"


# ─────────────────────────────────────────────────────────────
# Mouse drag input
# ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _pieces.is_empty() or _active_camera == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(get_viewport().get_mouse_position())
		else:
			_dragging = null

	elif event is InputEventMouseMotion and _dragging != null:
		_move_dragged(get_viewport().get_mouse_position())


func _try_grab(mouse_pos: Vector2) -> void:
	var best_piece: MeshInstance3D = null
	var best_dist:  float          = 90.0

	for piece in _pieces:
		var screen_pos: Vector2 = _active_camera.unproject_position(piece.global_position)
		var dist: float         = mouse_pos.distance_to(screen_pos)
		if dist < best_dist:
			best_dist  = dist
			best_piece = piece

	if best_piece == null:
		return

	_dragging   = best_piece
	_drag_plane = Plane(Vector3.UP, best_piece.global_position.y)

	var origin: Vector3 = _active_camera.project_ray_origin(mouse_pos)
	var dir:    Vector3 = _active_camera.project_ray_normal(mouse_pos)
	var hit:    Variant = _drag_plane.intersects_ray(origin, dir)
	if hit:
		_drag_offset = best_piece.global_position - (hit as Vector3)

		# Store offset of the other piece relative to the grabbed one
		for piece in _pieces:
			if piece != _dragging:
				_drag_offset_secondary = piece.global_position - best_piece.global_position
				break


func _move_dragged(mouse_pos: Vector2) -> void:
	var origin: Vector3 = _active_camera.project_ray_origin(mouse_pos)
	var dir:    Vector3 = _active_camera.project_ray_normal(mouse_pos)
	var hit:    Variant = _drag_plane.intersects_ray(origin, dir)
	if hit:
		var new_pos: Vector3          = (hit as Vector3) + _drag_offset
		_dragging.global_position     = new_pos

		# Move other piece maintaining its relative offset
		for piece in _pieces:
			if piece != _dragging:
				piece.global_position = new_pos + _drag_offset_secondary


# ─────────────────────────────────────────────────────────────
# Seam detection — runs every frame while dragging
# ─────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if _pieces.is_empty() or _dragging == null:
		return
	_check_seams()


func _check_seams() -> void:
	var radius: float   = _config.get("seam_radius", 0.04)
	var needle: Vector3 = needle_tip.global_position

	for i in _seam_markers.size():
		if _seam_done[i]:
			continue

		# global_position already accounts for piece position and rotation
		if _seam_markers[i].global_position.distance_to(needle) <= radius:
			_register_seam(i)
			break   # one seam per frame is enough


func _register_seam(index: int) -> void:
	_seam_done[index] = true
	_seams_completed += 1
	_refresh_ui()

	# Flash the piece this marker belongs to
	var marker_parent: Node = _seam_markers[index].get_parent()
	if marker_parent is MeshInstance3D:
		_flash_piece(marker_parent as MeshInstance3D)

	if _seams_completed >= _seam_markers.size():
		_finish_sewing()


# ─────────────────────────────────────────────────────────────
# Sewing complete
# ─────────────────────────────────────────────────────────────
func _finish_sewing() -> void:
	_dragging = null
	_pieces   = []
	sew_ui.visible = false

	# Shrink pieces out
	for piece in get_tree().get_nodes_in_group("sewing_pieces"):
		var t := create_tween()
		t.tween_property(piece, "scale", Vector3.ZERO, 0.28).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(0.32).timeout
	
	for piece in get_tree().get_nodes_in_group("sewing_pieces"):
		piece.visible = false

	# Load finished garment from config if not already in scene
	if finished_model == null and _config.has("finished_scene"):
		var packed: PackedScene = load(_config["finished_scene"])
		if packed:
			finished_model = packed.instantiate()
			add_child(finished_model)

	if finished_model:
		# ← NO position override — uses exactly where you placed it in the editor
		finished_model.visible = true
		finished_model.scale   = Vector3.ZERO

		var t_in := create_tween()
		t_in.tween_property(finished_model, "scale", Vector3(1.15, 1.15, 1.15), 0.30).set_ease(Tween.EASE_OUT)
		await t_in.finished
		var t_settle := create_tween()
		t_settle.tween_property(finished_model, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_IN_OUT)
		await t_settle.finished

	sew_ui.visible         = true
	progress_bar.visible   = false
	status_label.visible   = false
	hint_label.visible     = false
	texture_rect.visible   = true   # show texture rect now that sewing is done
	_store_button.visible  = true

	_store_button.modulate = Color(1, 1, 1, 0)
	var t_btn := create_tween()
	t_btn.tween_property(_store_button, "modulate", Color(1, 1, 1, 1), 0.35)


func _on_store_pressed() -> void:
	
	# Fade out the store button
	var t_btn := create_tween()
	t_btn.tween_property(_store_button, "modulate", Color(1, 1, 1, 0), 0.2)
	await t_btn.finished
	_store_button.visible = false
	texture_rect.visible  = false  # hide texture rect when order is stored

	# Shrink out the finished shirt
	if finished_model and finished_model.visible:
		var t_out := create_tween()
		t_out.tween_property(finished_model, "scale", Vector3.ZERO, 0.30).set_ease(Tween.EASE_IN)
		await t_out.finished
		finished_model.visible = false
		finished_model.scale   = Vector3.ONE   # reset for next use

	# Restore UI widget visibility for next round
	sew_ui.visible       = false
	progress_bar.visible = true
	status_label.visible = true
	hint_label.visible   = true

	emit_signal("sewing_complete")


# ─────────────────────────────────────────────────────────────
# UI + VFX helpers
# ─────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	var total: int = _seam_markers.size()
	if total == 0:
		progress_bar.value = 0
		status_label.text  = "Seams sewn: 0 / 0"
		return
	progress_bar.value = (float(_seams_completed) / float(total)) * 100.0
	status_label.text  = "Seams sewn: %d / %d" % [_seams_completed, total]


func _build_flash_material() -> void:
	_flash_mat                            = StandardMaterial3D.new()
	_flash_mat.albedo_color               = Color(1.0, 0.9, 0.3)
	_flash_mat.emission_enabled           = true
	_flash_mat.emission                   = Color(1.0, 0.8, 0.1)
	_flash_mat.emission_energy_multiplier = 1.2


func _flash_piece(piece: MeshInstance3D) -> void:
	var orig := piece.get_surface_override_material(0)
	piece.set_surface_override_material(0, _flash_mat)
	await get_tree().create_timer(0.16).timeout
	piece.set_surface_override_material(0, orig)
	
