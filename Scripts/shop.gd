# shop.gd
extends Node3D

@onready var enter_image: TextureRect    = $PauseCanvas/EnterImage
@onready var open_button: Button         = $PauseCanvas/EnterImage/OpenButton
@onready var hud_texture: TextureRect    = $PauseCanvas/HudTexture
@onready var level_label: Label          = $PauseCanvas/HudTexture/LevelLabel
@onready var xp_label:    Label          = $PauseCanvas/HudTexture/XPLabel
@onready var coins_label: Label          = $PauseCanvas/HudTexture/CoinLabel
@onready var sewing_machine: StaticBody3D = $sewing_machine

@export var customer_scene_berserker: PackedScene
@export var customer_scene_girl:      PackedScene


var _shop_open:       bool  = false
var _customer_active: bool  = false
var _spawn_girl_next: bool  = false


var _spawn_timer: Timer

# ── Delivery UI ───────────────────────────────────────────────────────────────
var _delivery_button:       Button         = null
var _pending_badge:         Label          = null

var _delivery_layer:        CanvasLayer    = null
var _delivery_panel:        Panel          = null
var _delivery_table_vbox:   VBoxContainer  = null
var _dispatch_feedback_lbl: Label          = null

# Fixed widths — must match between header and rows
const COL_CITY_W:    float = 0.0   # EXPAND_FILL
const COL_ORDERS_W:  float = 0.0   # EXPAND_FILL
const COL_REV_W:     float = 0.0   # EXPAND_FILL
const COL_ACTION_W:  float = 120.0 # fixed


func _ready() -> void:
	open_button.toggle_mode    = true
	open_button.button_pressed = false
	open_button.text           = "OFF"
	open_button.toggled.connect( _on_btn_toggled)  # use toggled instead of pressed

	_spawn_timer          = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_spawn_customer)
	add_child(_spawn_timer)

	GameManager.stats_changed.connect(_refresh_hud)
	_refresh_hud()

	sewing_machine.sewing_complete.connect(_on_sewing_complete)
	
	 # ── Fade in from black ─────────────────────────────────────────────
	var black_rect = ColorRect.new()
	black_rect.color = Color(0, 0, 0, 1)
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	$PauseCanvas.add_child(black_rect)

	var tween = create_tween()
	tween.tween_property(black_rect, "color", Color(0, 0, 0, 0), 1.0)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(black_rect.queue_free)

	_build_delivery_button()
	_build_delivery_panel()



# ─────────────────────────────────────────────────────────────────────────────
#  HUD
# ─────────────────────────────────────────────────────────────────────────────


func _refresh_hud() -> void:
	level_label.text  = str(GameManager.player_level)
	xp_label.text     = str(GameManager.player_xp) + " XP"
	coins_label.text  = str(GameManager.player_coins)

	if _pending_badge != null:
		var areas: Array = Database.get_top_delivery_areas(10)
		var total_undelivered: int = 0
		for a in areas:
			total_undelivered += int(a.get("Pending_deliveries", 0))
		_pending_badge.text    = str(total_undelivered) if total_undelivered > 0 else ""
		_pending_badge.visible = total_undelivered > 0



# ─────────────────────────────────────────────────────────────────────────────
#  Delivery button
# ─────────────────────────────────────────────────────────────────────────────

func _build_delivery_button() -> void:
	var btn_container := Control.new()
	btn_container.anchor_left   = 0.5
	btn_container.anchor_right  = 0.5
	btn_container.anchor_top    = 1.0
	btn_container.anchor_bottom = 1.0
	btn_container.offset_left   = -105
	btn_container.offset_right  =  105
	btn_container.offset_top    =  -54
	btn_container.offset_bottom =  -10
	get_node("PauseCanvas").add_child(btn_container)

	_delivery_button = Button.new()
	_delivery_button.text = "🚚  Dispatch Orders"
	_delivery_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_delivery_button.add_theme_font_size_override("font_size", 13)
	_delivery_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_delivery_button.pressed.connect(_open_delivery_panel)
	btn_container.add_child(_delivery_button)

	_pending_badge = Label.new()
	_pending_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pending_badge.position = Vector2(-20, -6)
	_pending_badge.add_theme_font_size_override("font_size", 11)
	_pending_badge.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	_pending_badge.visible = false
	btn_container.add_child(_pending_badge)


# ─────────────────────────────────────────────────────────────────────────────
#  Delivery dispatch panel
# ─────────────────────────────────────────────────────────────────────────────

func _build_delivery_panel() -> void:
	_delivery_layer = CanvasLayer.new()
	_delivery_layer.layer = 9
	add_child(_delivery_layer)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.60)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_delivery_layer.add_child(overlay)

	# Main panel
	_delivery_panel = Panel.new()
	_delivery_panel.set_anchors_preset(Control.PRESET_CENTER)
	_delivery_panel.custom_minimum_size = Vector2(700, 480)
	_delivery_panel.position = Vector2(-350, -240)
	_delivery_layer.add_child(_delivery_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 10)
	root_vbox.offset_left   =  14
	root_vbox.offset_top    =  14
	root_vbox.offset_right  = -14
	root_vbox.offset_bottom = -14
	_delivery_panel.add_child(root_vbox)

	# ── Title row ──
	var title_row := HBoxContainer.new()
	root_vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "🚚  DELIVERY DISPATCH"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	title_row.add_child(title_lbl)

	var refresh_btn := Button.new()
	refresh_btn.text = "↻ Refresh"
	refresh_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	refresh_btn.pressed.connect(_refresh_delivery_table)
	title_row.add_child(refresh_btn)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_delivery_panel)
	title_row.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# ── Subtitle ──
	var sub_lbl := Label.new()
	sub_lbl.text = "Top cities with completed orders awaiting delivery (Order_status = 'Completed', Payment_status = 'Unpaid')"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	root_vbox.add_child(sub_lbl)

	# ── Column headers ──
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 4)
	root_vbox.add_child(header_hbox)

	# The first three headers expand to fill; Action header is fixed-width
	# to align exactly with the Dispatch button in each row.
	for col_text in ["City", "Orders", "Est. Revenue"]:
		var h := Label.new()
		h.text = col_text
		h.add_theme_font_size_override("font_size", 13)
		h.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(h)

	# Action header — fixed width matching the dispatch button
	var action_h := Label.new()
	action_h.text = "Action"
	action_h.add_theme_font_size_override("font_size", 13)
	action_h.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	action_h.custom_minimum_size = Vector2(COL_ACTION_W, 0)
	action_h.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_hbox.add_child(action_h)

	root_vbox.add_child(HSeparator.new())

	# ── Scrollable table ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_delivery_table_vbox = VBoxContainer.new()
	_delivery_table_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delivery_table_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_delivery_table_vbox)

	root_vbox.add_child(HSeparator.new())

	# ── Feedback label ──
	_dispatch_feedback_lbl = Label.new()
	_dispatch_feedback_lbl.text = ""
	_dispatch_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dispatch_feedback_lbl.add_theme_font_size_override("font_size", 14)
	_dispatch_feedback_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	root_vbox.add_child(_dispatch_feedback_lbl)

	_delivery_layer.visible = false


func _open_delivery_panel() -> void:
	_dispatch_feedback_lbl.text = ""
	_refresh_delivery_table()
	_delivery_layer.visible = true


func _close_delivery_panel() -> void:
	_delivery_layer.visible = false


func _refresh_delivery_table() -> void:
	# Clear old rows
	for child in _delivery_table_vbox.get_children():
		child.queue_free()

	var areas: Array = Database.get_top_delivery_areas(5)

	if areas.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No completed orders awaiting delivery."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_delivery_table_vbox.add_child(empty_lbl)
		return

	for area in areas:
		_delivery_table_vbox.add_child(_build_area_row(area))


func _build_area_row(area: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var city_lbl := Label.new()
	city_lbl.text = area.get("City", "—")
	city_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(city_lbl)

	var count_lbl := Label.new()
	count_lbl.text = str(area.get("Pending_deliveries", 0)) + " order(s)"
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	hbox.add_child(count_lbl)

	var rev_lbl := Label.new()
	var rev: float = float(area.get("Area_revenue", 0.0))
	rev_lbl.text = str(int(rev)) + " coins" #round up now fixed to round down
	rev_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rev_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	hbox.add_child(rev_lbl)

	# Fixed-width dispatch button — matches Action header width
	var dispatch_btn := Button.new()
	dispatch_btn.text = "Dispatch →"
	dispatch_btn.custom_minimum_size = Vector2(COL_ACTION_W, 0)
	dispatch_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	dispatch_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var city_str: String = area.get("City", "")
	dispatch_btn.pressed.connect(func(): _dispatch_area(city_str))
	hbox.add_child(dispatch_btn)

	return hbox


# ── Dispatch all completed orders for a city ──────────────────────────────────
func _dispatch_area(city: String) -> void:
	if city.is_empty():
		return

	var result: Dictionary = Database.deliver_orders_for_area(city)
	var count:  int        = result.get("count",   0)
	var revenue: float     = result.get("revenue", 0.0)

	if count == 0:
		_dispatch_feedback_lbl.text = "No eligible orders found for %s." % city
		_dispatch_feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		return

	var xp_reward: int = count * 75
	Database.add_player_rewards(xp_reward, int(revenue))

	_dispatch_feedback_lbl.text = (
		"✅  Dispatched %d order(s) to %s  |  +%d XP  |  +%.0f coins!"
		% [count, city, xp_reward, revenue]
	)
	_dispatch_feedback_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

	_refresh_delivery_table()
	GameManager._sync_stats()

	print("Shop: Dispatched %d order(s) — %s — +%d XP  +%.2f coins"
		  % [count, city, xp_reward, revenue])


# ─────────────────────────────────────────────────────────────────────────────
#  Shop toggle + customer spawning
# ─────────────────────────────────────────────────────────────────────────────

func _on_btn_toggled(pressed: bool) -> void:
	_shop_open = pressed
	if pressed:
		open_button.text = "ON"
		_spawn_timer.start(randf_range(3.0, 10.0))
	else:
		open_button.text = "OFF"
		_spawn_timer.stop()



func _spawn_customer() -> void:
	# Reset button to OFF now that the customer is arriving
	open_button.button_pressed = false
	open_button.text           = "OFF"

	var customer

	if _spawn_girl_next:
		if customer_scene_girl == null:
			printerr("Error: customer_scene_girl is not assigned in the Inspector!")
			return
		customer = customer_scene_girl.instantiate()
		customer.scale = Vector3(1.2, 1.2, 1.2)
	else:
		if customer_scene_berserker == null:
			printerr("Error: customer_scene_berserker is not assigned in the Inspector!")
			return
		customer = customer_scene_berserker.instantiate()
		customer.scale = Vector3(1.3, 1.3, 1.3)

	_spawn_girl_next = not _spawn_girl_next

	add_child(customer)
	customer.global_position = Vector3(9.56, 0.0, -1.0)
	customer.customer_left.connect(_on_customer_left, CONNECT_ONE_SHOT)

	_customer_active = true


func _on_customer_left() -> void:
	_customer_active = false



func _close_shop() -> void:
	_shop_open                 = false
	open_button.button_pressed = false
	open_button.text           = "OFF"


# UI visibility during cutting / sewing
func on_cutting_started() -> void:
	enter_image.visible = false
	hud_texture.visible = false


func _on_sewing_complete() -> void:
	await get_tree().create_timer(0.6).timeout
	enter_image.visible = true
	hud_texture.visible = true
