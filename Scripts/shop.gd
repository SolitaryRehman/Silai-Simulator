extends Node3D

@onready var enter_image: TextureRect    = $PauseCanvas/EnterImage
@onready var open_button: Button         = $PauseCanvas/EnterImage/OpenButton
@onready var hud_texture: TextureRect    = $PauseCanvas/HudTexture
@onready var level_label: Label          = $PauseCanvas/HudTexture/LevelLabel
@onready var xp_label:    Label          = $PauseCanvas/HudTexture/XPLabel
@onready var coins_label: Label          = $PauseCanvas/HudTexture/CoinLabel
@onready var sewing_machine: StaticBody3D = $sewing_machine

# the two customer types — assigned in the Inspector
@export var customer_scene_berserker: PackedScene
@export var customer_scene_girl:      PackedScene


# tracks whether the shop sign is flipped to "open" by the player
var _shop_open:       bool  = false
# prevents a second customer from spawning before the first one leaves
var _customer_active: bool  = false
# alternates between the two customer types each visit
var _spawn_girl_next: bool  = false

# fires after a random delay to bring in the next customer
var _spawn_timer: Timer

# ── Delivery UI ───────────────────────────────────────────────────────────────
# the bottom-center button that opens the delivery dispatch panel
var _delivery_button:       Button         = null
# small red number badge that shows total pending deliveries at a glance
var _pending_badge:         Label          = null

# the overlay layer that contains the whole dispatch panel
var _delivery_layer:        CanvasLayer    = null
var _delivery_panel:        Panel          = null
# rows get rebuilt here every time the panel opens or refreshes
var _delivery_table_vbox:   VBoxContainer  = null
# shows success or error messages at the bottom of the panel after dispatching
var _dispatch_feedback_lbl: Label          = null

# shared column width so the header and data rows line up perfectly
const COL_ACTION_W: float = 140.0


func _ready() -> void:
	# toggle button starts in the OFF state — player has to manually open the shop
	open_button.toggle_mode    = true
	open_button.button_pressed = false
	open_button.text           = "OFF"
	open_button.toggled.connect(_on_btn_toggled)

	# one-shot timer so customers only arrive one at a time
	_spawn_timer          = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.timeout.connect(_spawn_customer)
	add_child(_spawn_timer)

	GameManager.stats_changed.connect(_refresh_hud)
	_refresh_hud()

	sewing_machine.sewing_complete.connect(_on_sewing_complete)

	# same black-to-transparent fade-in used on the main menu
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


func _refresh_hud() -> void:
	level_label.text = str(GameManager.player_level)
	xp_label.text    = str(GameManager.player_xp) + " XP"
	coins_label.text = str(GameManager.player_coins)

	# update the badge count every time stats change
	if _pending_badge != null:
		var areas: Array = Database.get_top_delivery_areas(10)
		var total_undelivered: int = 0
		for a in areas:
			total_undelivered += int(a.get("Pending_deliveries", 0))
		# hide the badge entirely when there's nothing pending
		_pending_badge.text    = str(total_undelivered) if total_undelivered > 0 else ""
		_pending_badge.visible = total_undelivered > 0


func _build_delivery_button() -> void:
	# anchor the button container to the bottom-center of the screen
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

	# the little red counter sits in the top-right corner of the button
	_pending_badge = Label.new()
	_pending_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pending_badge.position = Vector2(-20, -6)
	_pending_badge.add_theme_font_size_override("font_size", 11)
	_pending_badge.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	_pending_badge.visible = false
	btn_container.add_child(_pending_badge)


func _build_delivery_panel() -> void:
	# layer 9 puts the panel above most other UI so it always reads on top
	_delivery_layer = CanvasLayer.new()
	_delivery_layer.layer = 9
	add_child(_delivery_layer)

	# dim the background so the panel feels like a proper modal
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.60)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_delivery_layer.add_child(overlay)

	# center the panel on screen
	_delivery_panel = Panel.new()
	_delivery_panel.set_anchors_preset(Control.PRESET_CENTER)
	_delivery_panel.custom_minimum_size = Vector2(860, 560)
	_delivery_panel.position            = Vector2(-430, -280)
	_delivery_layer.add_child(_delivery_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 12)
	root_vbox.offset_left   =  18
	root_vbox.offset_top    =  16
	root_vbox.offset_right  = -18
	root_vbox.offset_bottom = -16
	_delivery_panel.add_child(root_vbox)

	# title row holds the heading plus refresh and close buttons on the right
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text                 = "🚚  DELIVERY DISPATCH"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	title_row.add_child(title_lbl)

	var refresh_btn := Button.new()
	refresh_btn.text               = "↻  Refresh"
	refresh_btn.custom_minimum_size = Vector2(110, 40)
	refresh_btn.add_theme_font_size_override("font_size", 15)
	refresh_btn.process_mode       = Node.PROCESS_MODE_ALWAYS
	refresh_btn.pressed.connect(_refresh_delivery_table)
	title_row.add_child(refresh_btn)

	var close_btn := Button.new()
	close_btn.text               = "✕  Close"
	close_btn.custom_minimum_size = Vector2(110, 40)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.process_mode       = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_delivery_panel)
	title_row.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# short description so the player knows exactly what this panel is showing
	var sub_lbl := Label.new()
	sub_lbl.text = "Top cities with completed orders awaiting delivery  (Order_status = 'Completed', Payment_status = 'Unpaid')"
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	root_vbox.add_child(sub_lbl)

	# column headers — must visually align with the data rows below
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 4)
	root_vbox.add_child(header_hbox)

	for col_text in ["City", "Orders", "Est. Revenue"]:
		var h := Label.new()
		h.text = col_text
		h.add_theme_font_size_override("font_size", 15)
		h.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(h)

	# action column is pinned to a fixed width so the Dispatch button never shifts
	var action_h := Label.new()
	action_h.text = "Action"
	action_h.add_theme_font_size_override("font_size", 15)
	action_h.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	action_h.custom_minimum_size   = Vector2(COL_ACTION_W, 0)
	action_h.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_hbox.add_child(action_h)

	root_vbox.add_child(HSeparator.new())

	# scroll container lets the list grow without blowing past the panel edges
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	# rows are cleared and rebuilt here every time the table refreshes
	_delivery_table_vbox = VBoxContainer.new()
	_delivery_table_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delivery_table_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_delivery_table_vbox)

	root_vbox.add_child(HSeparator.new())

	# lives at the bottom — shows dispatch results or errors after the player clicks
	_dispatch_feedback_lbl = Label.new()
	_dispatch_feedback_lbl.text               = ""
	_dispatch_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dispatch_feedback_lbl.add_theme_font_size_override("font_size", 16)
	_dispatch_feedback_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	root_vbox.add_child(_dispatch_feedback_lbl)

	# start hidden — only shown when the player opens it
	_delivery_layer.visible = false


func _open_delivery_panel() -> void:
	# clear last session's feedback message before showing fresh data
	_dispatch_feedback_lbl.text = ""
	_refresh_delivery_table()
	_delivery_layer.visible = true


func _close_delivery_panel() -> void:
	_delivery_layer.visible = false


func _refresh_delivery_table() -> void:
	# wipe existing rows before rebuilding so stale data doesn't linger
	for child in _delivery_table_vbox.get_children():
		child.queue_free()

	var areas: Array = Database.get_top_delivery_areas(5)

	if areas.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text                  = "No completed orders awaiting delivery."
		empty_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_delivery_table_vbox.add_child(empty_lbl)
		return

	for area in areas:
		_delivery_table_vbox.add_child(_build_area_row(area))


func _build_area_row(area: Dictionary) -> PanelContainer:
	# each city gets its own dark card so rows are visually separated
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.14, 0.16, 0.22, 0.92)
	style.border_color = Color(0.35, 0.40, 0.60, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	card.add_child(hbox)

	var city_lbl := Label.new()
	city_lbl.text                  = area.get("City", "—")
	city_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_lbl.add_theme_font_size_override("font_size", 17)
	city_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hbox.add_child(city_lbl)

	# order count in gold to make it pop against the dark card
	var count_lbl := Label.new()
	count_lbl.text                  = str(area.get("Pending_deliveries", 0)) + " order(s)"
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_lbl.add_theme_font_size_override("font_size", 17)
	count_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	hbox.add_child(count_lbl)

	# revenue in green so it reads as money at a glance
	var rev_lbl := Label.new()
	var rev: float = float(area.get("Area_revenue", 0.0))
	rev_lbl.text                  = str(int(rev)) + " coins"
	rev_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rev_lbl.add_theme_font_size_override("font_size", 17)
	rev_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	hbox.add_child(rev_lbl)

	# capture city in a local variable so the lambda closure doesn't go stale
	var dispatch_btn := Button.new()
	dispatch_btn.text               = "Dispatch  →"
	dispatch_btn.custom_minimum_size = Vector2(COL_ACTION_W, 44)
	dispatch_btn.add_theme_font_size_override("font_size", 15)
	dispatch_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	dispatch_btn.process_mode          = Node.PROCESS_MODE_ALWAYS
	var city_str: String = area.get("City", "")
	dispatch_btn.pressed.connect(func(): _dispatch_area(city_str))
	hbox.add_child(dispatch_btn)

	return card


func _dispatch_area(city: String) -> void:
	if city.is_empty():
		return

	var result:  Dictionary = Database.deliver_orders_for_area(city)
	var count:   int        = result.get("count",   0)
	var revenue: float      = result.get("revenue", 0.0)

	# database found nothing eligible — tell the player instead of silently doing nothing
	if count == 0:
		_dispatch_feedback_lbl.text = "No eligible orders found for %s." % city
		_dispatch_feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		return

	# 75 XP per dispatched order — scales naturally with how busy the shop is
	var xp_reward: int = count * 75
	Database.add_player_rewards(xp_reward, int(revenue))

	_dispatch_feedback_lbl.text = (
		"✅  Dispatched %d order(s) to %s  |  +%d XP  |  +%.0f coins!"
		% [count, city, xp_reward, revenue]
	)
	_dispatch_feedback_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

	# rebuild the table immediately so the dispatched city disappears or updates
	_refresh_delivery_table()
	GameManager._sync_stats()

	print("Shop: Dispatched %d order(s) — %s — +%d XP  +%.2f coins"
		  % [count, city, xp_reward, revenue])


func _on_btn_toggled(pressed: bool) -> void:
	_shop_open = pressed
	if pressed:
		open_button.text = "ON"
		# random delay between 3–10 seconds keeps customer arrivals feeling natural
		_spawn_timer.start(randf_range(3.0, 10.0))
	else:
		open_button.text = "OFF"
		_spawn_timer.stop()


func _spawn_customer() -> void:
	# flip the sign back to OFF — shop closes between each customer visit
	open_button.button_pressed = false
	open_button.text           = "OFF"

	var customer

	# alternate between the two customer types every visit
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
	# spawn point is just off to the side — the customer walks in from here
	customer.global_position = Vector3(9.56, 0.0, -1.0)
	# one-shot so we don't stack up callbacks if something goes wrong
	customer.customer_left.connect(_on_customer_left, CONNECT_ONE_SHOT)

	_customer_active = true


func _on_customer_left() -> void:
	_customer_active = false


func _close_shop() -> void:
	_shop_open                 = false
	open_button.button_pressed = false
	open_button.text           = "OFF"


func on_cutting_started() -> void:
	# hide the shop UI while the player is busy at the cutting table
	enter_image.visible = false
	hud_texture.visible = false


func _on_sewing_complete() -> void:
	# short pause so the garment pop-in animation finishes before the UI comes back
	await get_tree().create_timer(0.6).timeout
	enter_image.visible = true
	hud_texture.visible = true
