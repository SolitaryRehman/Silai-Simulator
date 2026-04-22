extends Node3D

signal sewing_complete

# ── Scene refs ────────────────────────────────────────────────
@onready var needle_tip:     Node3D      = $needle_tip
@onready var sew_ui:         CanvasLayer = $sew_ui
@onready var progress_bar:   ProgressBar = $sew_ui/progress_bar
@onready var status_label:   Label       = $sew_ui/status_label
@onready var hint_label:     Label       = $sew_ui/hint_label
@onready var finished_model: Node3D      = $finished_model

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

	# Collect every Marker3D child tagged "seam_point" from all pieces
	for piece in _pieces:
		for child in piece.get_children():
			if child is Marker3D and child.is_in_group("seam_point"):
				_seam_markers.append(child)
				_seam_done.append(false)

	print("Seam markers found: ", _seam_markers.size())

	_spawn_debug_seam_markers()
	_refresh_ui()
	sew_ui.visible  = true
	hint_label.text = "Drag pieces — guide each seam edge to the needle"


# ─────────────────────────────────────────────────────────────
# Debug markers — remove _spawn_debug_seam_markers() call
# from begin_sewing() once seam points look correct
# ─────────────────────────────────────────────────────────────
func _spawn_debug_seam_markers() -> void:
	# Clean up previous debug markers
	for child in get_tree().root.get_children():
		if child.is_in_group("debug_seam"):
			child.queue_free()

	# Red sphere at each seam marker
	for marker in _seam_markers:
		var m   := MeshInstance3D.new()
		var s   := SphereMesh.new()
		s.radius = 0.03
		s.height = 0.06
		m.mesh   = s
		var mat             := StandardMaterial3D.new()
		mat.albedo_color     = Color(1, 0, 0)
		mat.emission_enabled = true
		mat.emission         = Color(1, 0, 0)
		m.set_surface_override_material(0, mat)
		m.add_to_group("debug_seam")
		get_tree().root.add_child(m)
		m.global_position = marker.global_position
		print("Seam marker at: ", marker.global_position)

	# Green sphere at needle tip
	var n   := MeshInstance3D.new()
	var s2  := SphereMesh.new()
	s2.radius = 0.03
	s2.height = 0.06
	n.mesh    = s2
	var mat2             := StandardMaterial3D.new()
	mat2.albedo_color     = Color(0, 1, 0)
	mat2.emission_enabled = true
	mat2.emission         = Color(0, 1, 0)
	n.set_surface_override_material(0, mat2)
	n.add_to_group("debug_seam")
	get_tree().root.add_child(n)
	n.global_position = needle_tip.global_position
	print("Needle at: ", needle_tip.global_position)


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
	var radius: float   = _config.get("seam_radius", 0.15)
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

	# Clean up debug markers
	for child in get_tree().root.get_children():
		if child.is_in_group("debug_seam"):
			child.queue_free()

	# Shrink pieces out
	for piece in get_tree().get_nodes_in_group("sewing_pieces"):
		var t := create_tween()
		t.tween_property(piece, "scale", Vector3.ZERO, 0.28).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.32).timeout

	# Load finished garment from config if not already in scene
	if finished_model == null and _config.has("finished_scene"):
		var packed: PackedScene = load(_config["finished_scene"])
		if packed:
			finished_model = packed.instantiate()
			add_child(finished_model)
			finished_model.global_position = needle_tip.global_position

	if finished_model:
		finished_model.visible = true
		finished_model.scale   = Vector3.ZERO
		var t2 := create_tween()
		t2.tween_property(finished_model, "scale", Vector3.ONE, 0.4).set_ease(Tween.EASE_OUT)

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
