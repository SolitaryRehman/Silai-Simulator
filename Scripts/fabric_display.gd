extends Control
 
# ─────────────────────────────────────────────
#  This node lives as a child of CuttingMinigame
#  It handles ALL drawing: fabric, dotted lines,
#  cut trail, and the scissors cursor.
# ─────────────────────────────────────────────
 
@onready var minigame: CanvasLayer = get_parent()
 
 
func _draw():
	if not minigame.visible:
		return
 
	var garment = minigame.current_garment
	if not minigame.PATTERNS.has(garment):
		return
 
	var pattern = minigame.PATTERNS[garment]
 
	# ── Draw fabric background ──
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.18, 0.50, 0.68, 1.0))
 
	# ── Draw each pattern piece outline ──
	for i in range(pattern["cut_lines"].size()):
		var line_points = pattern["cut_lines"][i]
 
		if i in minigame.lines_completed:
			# Already cut → green solid line
			_draw_dotted_polygon(line_points, Color(0.2, 0.95, 0.3, 1.0), 3.0)
		elif i == minigame.active_line_index:
			# Currently cutting → bright white dotted
			_draw_dotted_polygon(line_points, Color(1.0, 1.0, 1.0, 1.0), 2.5)
		else:
			# Not yet reached → dim white dotted
			_draw_dotted_polygon(line_points, Color(1.0, 1.0, 1.0, 0.35), 2.0)
 
	# ── Draw the cut trail the player has made ──
	if minigame.cut_path.size() > 1:
		for i in range(minigame.cut_path.size() - 1):
			draw_line(
				minigame.cut_path[i],
				minigame.cut_path[i + 1],
				Color(1.0, 0.85, 0.1, 0.85),
				2.5
			)
 
	# ── Draw scissors at current mouse position ──
	_draw_scissors(minigame.scissors_pos)
 
 
# ─────────────────────────────────────────────
#  Draw a dotted/dashed polygon outline
#  points  → array of Vector2 vertices
#  color   → line color
#  width   → line thickness in px
# ─────────────────────────────────────────────
func _draw_dotted_polygon(points: Array, color: Color, width: float):
	for i in range(points.size()):
		var start = points[i]
		var end = points[(i + 1) % points.size()]
		var total_dist = start.distance_to(end)
		var dot_len = 8.0
		var gap_len = 6.0
		var segment = dot_len + gap_len
		var num_segments = int(total_dist / segment)
 
		for d in range(num_segments):
			var t_start = (float(d) * segment) / total_dist
			var t_end = (float(d) * segment + dot_len) / total_dist
			t_end = min(t_end, 1.0)
			var p1 = start.lerp(end, t_start)
			var p2 = start.lerp(end, t_end)
			draw_line(p1, p2, color, width)
 
 
# ─────────────────────────────────────────────
#  Draw a simple scissors icon at pos
# ─────────────────────────────────────────────
func _draw_scissors(pos: Vector2):
	if pos == Vector2.ZERO:
		return
 
	var silver = Color(0.78, 0.78, 0.82, 1.0)
	var green = Color(0.18, 0.72, 0.22, 1.0)
	var blade_len = 18.0
	var handle_len = 12.0
 
	# Pivot circle
	draw_circle(pos, 4.0, silver)
 
	# Blades
	draw_line(pos, pos + Vector2(blade_len, blade_len), silver, 2.5)
	draw_line(pos, pos + Vector2(-blade_len, blade_len), silver, 2.5)
 
	# Handles (green rings)
	draw_arc(pos + Vector2(blade_len + handle_len, blade_len), 6.0, 0, TAU, 16, green, 2.5)
	draw_arc(pos + Vector2(-blade_len - handle_len, blade_len), 6.0, 0, TAU, 16, green, 2.5)
