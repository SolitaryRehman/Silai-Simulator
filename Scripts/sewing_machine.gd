extends Node3D

signal sewing_complete

# everything this node needs to do its job
@onready var needle_tip:     Node3D      = $needle_tip
@onready var sew_ui:         CanvasLayer = $sew_ui
@onready var progress_bar:   ProgressBar = $sew_ui/progress_bar
@onready var status_label:   Label       = $sew_ui/status_label
@onready var hint_label:     Label       = $sew_ui/hint_label
@onready var finished_model: Node3D      = $finished_model
@onready var texture_rect: TextureRect = $sew_ui/TextureRect
@onready var _store_button: Button = $sew_ui/TextureRect/store_button


# the fabric pieces currently on the table waiting to be sewn
var _pieces:        Array      = []
# clothing-type config (seam radius, finished scene path, etc.)
var _config:        Dictionary = {}
# whichever camera is active so we can do screen-space drag math
var _active_camera: Camera3D   = null

# the piece the player is currently dragging
var _dragging:             MeshInstance3D = null
# horizontal plane at the piece's height — drag stays on this flat surface
var _drag_plane:           Plane
# offset between the click point and the piece center so it doesn't snap to your cursor
var _drag_offset:          Vector3
# keeps the second piece's relative position locked to the dragged one
var _drag_offset_secondary: Vector3

# each Marker3D child on a piece represents one seam point to reach
var _seam_markers:    Array[Marker3D] = []
# parallel bool array — true once that marker has touched the needle
var _seam_done:       Array[bool]     = []
# running count of how many seams are done so we know when to finish
var _seams_completed: int             = 0

# bright yellow flash material slapped on a piece when a seam registers
var _flash_mat: StandardMaterial3D


func _ready() -> void:
	# UI and finished garment stay hidden until the player actually starts sewing
	sew_ui.visible = false
	if finished_model:
		finished_model.visible = false
	_store_button.text = "STORE"
	_store_button.visible = false
	_store_button.pressed.connect(_on_store_pressed)
	# texture rect is the completion frame — hide it until the job is done
	texture_rect.visible = false
	_build_flash_material()


func begin_sewing(pieces: Array, clothing_type: String, camera: Camera3D) -> void:
	_pieces          = pieces
	_config          = ClothingConfig.get_config(clothing_type)
	_active_camera   = camera
	_seams_completed = 0
	_seam_markers.clear()
	_seam_done.clear()

	# reset pieces in case they're being reused from a previous round
	for piece in _pieces:
		piece.visible = true
		piece.scale   = Vector3.ONE

	# collect every seam marker across all pieces into one flat list
	for piece in _pieces:
		for child in piece.get_children():
			if child is Marker3D and child.is_in_group("seam_point"):
				_seam_markers.append(child)
				_seam_done.append(false)

	_refresh_ui()
	sew_ui.visible  = true
	hint_label.text = "Drag pieces — guide each seam edge to the needle"


func _input(event: InputEvent) -> void:
	# ignore all input if there's nothing to sew or no camera to unproject with
	if _pieces.is_empty() or _active_camera == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(get_viewport().get_mouse_position())
		else:
			# drop whatever we were dragging on mouse release
			_dragging = null

	elif event is InputEventMouseMotion and _dragging != null:
		_move_dragged(get_viewport().get_mouse_position())


func _try_grab(mouse_pos: Vector2) -> void:
	# find whichever piece's screen position is closest to where the player clicked
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
	# horizontal drag plane sits at the piece's current height
	_drag_plane = Plane(Vector3.UP, best_piece.global_position.y)

	# figure out where in world space the player actually clicked
	var origin: Vector3 = _active_camera.project_ray_origin(mouse_pos)
	var dir:    Vector3 = _active_camera.project_ray_normal(mouse_pos)
	var hit:    Variant = _drag_plane.intersects_ray(origin, dir)
	if hit:
		# store offset so the piece doesn't jump to the cursor on pickup
		_drag_offset = best_piece.global_position - (hit as Vector3)

		# lock the other piece's position relative to the grabbed one
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

		# drag both pieces together so they move as a unit
		for piece in _pieces:
			if piece != _dragging:
				piece.global_position = new_pos + _drag_offset_secondary


func _process(_delta: float) -> void:
	# only bother checking seams while the player is actively dragging
	if _pieces.is_empty() or _dragging == null:
		return
	_check_seams()


func _check_seams() -> void:
	var radius: float   = _config.get("seam_radius", 0.04)
	var needle: Vector3 = needle_tip.global_position

	for i in _seam_markers.size():
		if _seam_done[i]:
			continue

		# if this marker is close enough to the needle tip, count it as sewn
		if _seam_markers[i].global_position.distance_to(needle) <= radius:
			_register_seam(i)
			# one seam per frame is plenty — avoid double-counting on the same tick
			break


func _register_seam(index: int) -> void:
	_seam_done[index] = true
	_seams_completed += 1
	_refresh_ui()

	# flash the piece this seam belongs to so the player gets clear feedback
	var marker_parent: Node = _seam_markers[index].get_parent()
	if marker_parent is MeshInstance3D:
		_flash_piece(marker_parent as MeshInstance3D)

	# if every seam is done, wrap it up
	if _seams_completed >= _seam_markers.size():
		_finish_sewing()


func _finish_sewing() -> void:
	_dragging = null
	_pieces   = []
	sew_ui.visible = false

	# shrink all pieces out before showing the finished garment
	for piece in get_tree().get_nodes_in_group("sewing_pieces"):
		var t := create_tween()
		t.tween_property(piece, "scale", Vector3.ZERO, 0.28).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(0.32).timeout
	
	for piece in get_tree().get_nodes_in_group("sewing_pieces"):
		piece.visible = false

	# support dynamically loaded garments in case it wasn't placed in the scene manually
	if finished_model == null and _config.has("finished_scene"):
		var packed: PackedScene = load(_config["finished_scene"])
		if packed:
			finished_model = packed.instantiate()
			add_child(finished_model)

	if finished_model:
		finished_model.visible = true
		finished_model.scale   = Vector3.ZERO

		# pop the garment in with a slight overshoot then settle to normal size
		var t_in := create_tween()
		t_in.tween_property(finished_model, "scale", Vector3(1.15, 1.15, 1.15), 0.30).set_ease(Tween.EASE_OUT)
		await t_in.finished
		var t_settle := create_tween()
		t_settle.tween_property(finished_model, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_IN_OUT)
		await t_settle.finished

	# swap the sewing UI for the completion UI
	sew_ui.visible         = true
	progress_bar.visible   = false
	status_label.visible   = false
	hint_label.visible     = false
	texture_rect.visible   = true
	_store_button.visible  = true

	# fade the store button in gently instead of popping it on screen
	_store_button.modulate = Color(1, 1, 1, 0)
	var t_btn := create_tween()
	t_btn.tween_property(_store_button, "modulate", Color(1, 1, 1, 1), 0.35)


func _on_store_pressed() -> void:
	# fade out the button before hiding anything so the transition feels intentional
	var t_btn := create_tween()
	t_btn.tween_property(_store_button, "modulate", Color(1, 1, 1, 0), 0.2)
	await t_btn.finished
	_store_button.visible = false
	texture_rect.visible  = false

	# shrink the finished garment out before resetting state
	if finished_model and finished_model.visible:
		var t_out := create_tween()
		t_out.tween_property(finished_model, "scale", Vector3.ZERO, 0.30).set_ease(Tween.EASE_IN)
		await t_out.finished
		finished_model.visible = false
		# reset scale so it's ready to be used cleanly next round
		finished_model.scale   = Vector3.ONE

	# restore sewing UI to its initial state for the next order
	sew_ui.visible       = false
	progress_bar.visible = true
	status_label.visible = true
	hint_label.visible   = true

	emit_signal("sewing_complete")


func _refresh_ui() -> void:
	var total: int = _seam_markers.size()
	if total == 0:
		progress_bar.value = 0
		status_label.text  = "Seams sewn: 0 / 0"
		return
	# scale completed seams to 0–100 for the progress bar
	progress_bar.value = (float(_seams_completed) / float(total)) * 100.0
	status_label.text  = "Seams sewn: %d / %d" % [_seams_completed, total]


func _build_flash_material() -> void:
	# warm yellow-gold emission material used for the seam-hit feedback flash
	_flash_mat                            = StandardMaterial3D.new()
	_flash_mat.albedo_color               = Color(1.0, 0.9, 0.3)
	_flash_mat.emission_enabled           = true
	_flash_mat.emission                   = Color(1.0, 0.8, 0.1)
	_flash_mat.emission_energy_multiplier = 1.2


func _flash_piece(piece: MeshInstance3D) -> void:
	# swap in the flash material for a split second then restore whatever was there before
	var orig := piece.get_surface_override_material(0)
	piece.set_surface_override_material(0, _flash_mat)
	await get_tree().create_timer(0.16).timeout
	piece.set_surface_override_material(0, orig)
