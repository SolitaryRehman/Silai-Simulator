extends CanvasLayer
 
# ─────────────────────────────────────────────
#  Child node references
# ─────────────────────────────────────────────
@onready var fabric_display: Control = $FabricDisplay
@onready var progress_bar: ProgressBar = $UI/ProgressBar
@onready var complete_button: Button = $UI/CompleteButton
@onready var escape_hint: Label = $UI/EscapeHint
@onready var background: ColorRect = $Background
 
 
# ─────────────────────────────────────────────
#  Cut line patterns for each garment
#  Each entry has:
#    pieces  → how many pattern pieces to cut
#    cut_lines → array of Vector2 arrays (one per piece)
#
#  These Vector2 coords are in screen/Control space.
#  Adjust values to match your FabricDisplay size.
# ─────────────────────────────────────────────
const PATTERNS = {
	"tshirt": {
		"pieces": 2,
		"cut_lines": [
			# Front piece
			[
				Vector2(100, 80),
				Vector2(160, 60),
				Vector2(220, 60),
				Vector2(280, 80),
				Vector2(300, 130),
				Vector2(300, 340),
				Vector2(100, 340),
				Vector2(100, 80)
			],
			# Back piece
			[
				Vector2(380, 80),
				Vector2(440, 60),
				Vector2(500, 60),
				Vector2(560, 80),
				Vector2(580, 130),
				Vector2(580, 340),
				Vector2(380, 340),
				Vector2(380, 80)
			]
		]
	},
	"pants": {
		"pieces": 2,
		"cut_lines": [
			# Left leg
			[
				Vector2(80, 60),
				Vector2(260, 60),
				Vector2(280, 280),
				Vector2(200, 480),
				Vector2(140, 480),
				Vector2(60, 280),
				Vector2(80, 60)
			],
			# Right leg
			[
				Vector2(340, 60),
				Vector2(520, 60),
				Vector2(540, 280),
				Vector2(460, 480),
				Vector2(400, 480),
				Vector2(320, 280),
				Vector2(340, 60)
			]
		]
	}
}
 
 
# ─────────────────────────────────────────────
#  Runtime state
# ─────────────────────────────────────────────
var current_garment: String = ""
var active_line_index: int = 0
var cut_progress: float = 0.0
var cut_path: Array = []
var lines_completed: Array = []
var scissors_pos: Vector2 = Vector2.ZERO
 
 
signal cutting_complete
signal cutting_cancelled
 
 
func _ready():
	hide()
	complete_button.connect("pressed", _on_complete_pressed)
	complete_button.visible = false
 
 
# ─────────────────────────────────────────────
#  Called by CuttingTable to begin the minigame
# ─────────────────────────────────────────────
func start_minigame(garment_type: String):
	current_garment = garment_type
	cut_progress = 0.0
	active_line_index = 0
	cut_path.clear()
	lines_completed.clear()
	complete_button.visible = false
	progress_bar.value = 0
 
	if PATTERNS.has(garment_type):
		scissors_pos = PATTERNS[garment_type]["cut_lines"][0][0]
 
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fabric_display.queue_redraw()
 
 
func _process(_delta):
	if not visible:
		return
 
	# ESC cancels the minigame
	if Input.is_action_just_pressed("ui_cancel"):
		_cancel_minigame()
		return
 
	# Hold left mouse button to cut along the dotted line
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos = fabric_display.get_local_mouse_position()
		_try_cut(mouse_pos)
 
	fabric_display.queue_redraw()
 
 
# ─────────────────────────────────────────────
#  Core cutting logic
# ─────────────────────────────────────────────
func _try_cut(mouse_pos: Vector2):
	if not PATTERNS.has(current_garment):
		return
 
	var pattern = PATTERNS[current_garment]
 
	# All pieces already cut
	if active_line_index >= pattern["pieces"]:
		return
 
	var current_line = pattern["cut_lines"][active_line_index]
	var closest_point = _get_closest_point_on_path(mouse_pos, current_line)
	var dist_to_line = mouse_pos.distance_to(closest_point)
 
	# Must be within 20px of the dotted outline
	if dist_to_line > 20.0:
		return
 
	scissors_pos = mouse_pos
 
	# Only add a new stitch point if far enough from the last one
	if cut_path.is_empty() or mouse_pos.distance_to(cut_path[-1]) > 6.0:
		cut_path.append(mouse_pos)
 
	# Calculate how far along this piece the player has cut
	var line_progress = _get_progress_along_path(mouse_pos, current_line)
	var piece_fraction = 1.0 / float(pattern["pieces"])
	cut_progress = (float(active_line_index) * piece_fraction + line_progress * piece_fraction) * 100.0
	progress_bar.value = cut_progress
 
	# Piece complete when player reaches ~95% of the outline
	if line_progress >= 0.95:
		_complete_piece()
 
 
func _complete_piece():
	lines_completed.append(active_line_index)
	active_line_index += 1
	cut_path.clear()
 
	var pattern = PATTERNS[current_garment]
	if active_line_index >= pattern["pieces"]:
		# All pieces done
		cut_progress = 100.0
		progress_bar.value = 100.0
		complete_button.visible = true
		print("All pieces cut! Press Complete.")
	else:
		# Start scissors at the beginning of the next piece
		scissors_pos = pattern["cut_lines"][active_line_index][0]
 
 
# ─────────────────────────────────────────────
#  Path math helpers
# ─────────────────────────────────────────────
func _get_closest_point_on_path(point: Vector2, path: Array) -> Vector2:
	var closest = path[0]
	var min_dist = point.distance_to(path[0])
	for p in path:
		var d = point.distance_to(p)
		if d < min_dist:
			min_dist = d
			closest = p
	return closest
 
 
func _get_progress_along_path(point: Vector2, path: Array) -> float:
	if path.is_empty():
		return 0.0
	var closest_idx = 0
	var min_dist = point.distance_to(path[0])
	for i in range(path.size()):
		var d = point.distance_to(path[i])
		if d < min_dist:
			min_dist = d
			closest_idx = i
	return float(closest_idx) / float(path.size() - 1)
 
 
# ─────────────────────────────────────────────
#  Button / signal handlers
# ─────────────────────────────────────────────
func _on_complete_pressed():
	GameManager.complete_cutting()
	hide()
	emit_signal("cutting_complete")
 
 
func _cancel_minigame():
	hide()
	GameManager.current_state = GameManager.GameState.FREE_ROAM
	emit_signal("cutting_cancelled")
