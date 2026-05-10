# berserk_armor.gd
extends CharacterBody3D

# grab all the nodes we need upfront
@onready var animation_player: AnimationPlayer = $armor/GeneralSkeleton/AnimationPlayer
@onready var interaction_label: Label3D        = $InteractionLabel
@onready var order_ui: Panel                   = $CanvasLayer/OrderUI
@onready var close_button: Button              = $CanvasLayer/OrderUI/CloseButton
@onready var accept_button: Button             = $CanvasLayer/OrderUI/AcceptButton

# how fast he walks, where he stops, which animation plays when idle, etc.
@export var move_speed:         float   = 1.50
@export var target_z:           float   = 10.0
@export var idle_anim:          String  = "idle_2/mixamo_com"
@export var interact_distance:  float   = 2.0
@export var label_appear_delay: float   = 1.0

# customer info pulled from the database
var _customer_data: Dictionary = {}
var _customer_name: String     = ""

# flags to track what the customer is doing right now
var _walking:          bool       = true
var _idle_done:        bool       = false
var _player:           Node3D     = null
var _order_pending:    bool       = false
var _order_generated:  bool       = false
var _current_order:    Dictionary = {}
var _leaving:          bool       = false

# little popup that shows the price after accepting
var _price_popup: Panel = null
var _price_label: Label = null
var _price_timer: float = 0.0
var _show_popup:  bool  = false

# the main order UI we build in code
var _order_canvas:      CanvasLayer   = null
var _dress_list_vbox:   VBoxContainer = null
var _cust_name_lbl:     Label         = null
var _cust_type_lbl:     Label         = null
var _custom_accept_btn: Button        = null

signal customer_left


func _ready() -> void:
	# hide UI stuff until we actually need it
	interaction_label.visible = false
	order_ui.visible          = false
	animation_player.play("Walk_Formal")
	_player = get_tree().get_first_node_in_group("player")

	# keep the old scene buttons wired up so nothing errors out
	close_button.pressed.connect(_close_order_ui)
	accept_button.pressed.connect(_accept_order)

	# listen for when a garment gets sewn so we can mark the order done
	GameManager.garment_sewn.connect(_on_garment_sewn)

	# pick a random customer name and load or create their DB record
	_customer_name = Database.get_random_name()
	_customer_data = Database.get_or_create_customer(_customer_name)
	_customer_name = _customer_data.get("Name", _customer_name)

	_print_customer_info()
	_build_price_popup()
	_build_order_ui()

	# disable collision for a couple seconds so he doesn't block the doorway coming in
	_set_collision(false)
	await get_tree().create_timer(2.5).timeout
	_set_collision(true)


# ── Price popup ───────────────────────────────────────────────────────────────

func _build_price_popup() -> void:
	# small centered popup, sits above everything else
	_price_popup = Panel.new()
	_price_popup.set_anchors_preset(Control.PRESET_CENTER)
	_price_popup.custom_minimum_size = Vector2(360, 130)
	_price_popup.offset_left   = -180
	_price_popup.offset_right  =  180
	_price_popup.offset_top    =  -65
	_price_popup.offset_bottom =   65
	_price_popup.z_index       = 10

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.offset_left   =  14
	vbox.offset_top    =  12
	vbox.offset_right  = -14
	vbox.offset_bottom = -12
	_price_popup.add_child(vbox)

	# green checkmark header
	var ok_lbl := Label.new()
	ok_lbl.text                 = "✅  Order Accepted!"
	ok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_lbl.add_theme_font_size_override("font_size", 17)
	vbox.add_child(ok_lbl)

	# this is where the actual coin amount goes
	_price_label = Label.new()
	_price_label.text                 = "Total Price: — coins"
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.add_theme_font_size_override("font_size", 22)
	_price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(_price_label)

	# small note reminding the player when they actually get paid
	var note := Label.new()
	note.text                 = "Paid at dispatch  (Σ unit_cost × qty)"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(note)

	$CanvasLayer.add_child(_price_popup)
	_price_popup.visible = false


# ── Custom order UI ───────────────────────────────────────────────────────────

func _build_order_ui() -> void:
	# new canvas layer so it draws on top of the game world
	_order_canvas = CanvasLayer.new()
	_order_canvas.layer        = 10
	_order_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_order_canvas)

	# dim the background so the panel stands out
	var overlay := ColorRect.new()
	overlay.color        = Color(0.0, 0.0, 0.0, 0.60)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_order_canvas.add_child(overlay)

	# main panel, centered on screen
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(860, 640)
	panel.offset_left         = -430
	panel.offset_right        =  430
	panel.offset_top          = -320
	panel.offset_bottom       =  320
	panel.process_mode        = Node.PROCESS_MODE_ALWAYS
	_order_canvas.add_child(panel)

	# everything stacks vertically inside the panel
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.offset_left   =  20
	root.offset_top    =  16
	root.offset_right  = -20
	root.offset_bottom = -16
	panel.add_child(root)

	# gold title at the top
	var title_lbl := Label.new()
	title_lbl.text                 = "✂   ORDER DETAILS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	root.add_child(title_lbl)

	# customer name on the left, their type badge on the right
	var cust_row := HBoxContainer.new()
	cust_row.add_theme_constant_override("separation", 12)
	root.add_child(cust_row)

	_cust_name_lbl = Label.new()
	_cust_name_lbl.add_theme_font_size_override("font_size", 19)
	_cust_name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_cust_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cust_row.add_child(_cust_name_lbl)

	# shows VIP / Rude / Normal with matching colour
	_cust_type_lbl = Label.new()
	_cust_type_lbl.add_theme_font_size_override("font_size", 16)
	cust_row.add_child(_cust_type_lbl)

	root.add_child(HSeparator.new())

	# scrollable area in case there are a lot of dresses
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	root.add_child(scroll)

	# actual dress rows get added here dynamically when the UI opens
	_dress_list_vbox = VBoxContainer.new()
	_dress_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dress_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_dress_list_vbox)

	root.add_child(HSeparator.new())

	# close and accept sit side by side at the bottom
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text                = "✕   Close"
	close_btn.custom_minimum_size = Vector2(160, 46)
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_order_ui)
	btn_row.add_child(close_btn)

	_custom_accept_btn = Button.new()
	_custom_accept_btn.text                = "✓   Accept Order"
	_custom_accept_btn.custom_minimum_size = Vector2(200, 46)
	_custom_accept_btn.add_theme_font_size_override("font_size", 17)
	_custom_accept_btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	_custom_accept_btn.pressed.connect(_accept_order)
	btn_row.add_child(_custom_accept_btn)

	# start hidden, only show when player interacts
	_order_canvas.visible = false


# just a debug print so we can see who walked in
func _print_customer_info() -> void:
	var ctype: String = _customer_data.get("customer_type", "Normal")
	print("━━━ Customer Arrived (Berserk) ━━━")
	print("  Name: ", _customer_name, "  [", ctype, "]")
	print("  City: ", _customer_data.get("City", "?"))
	var cid: int = _customer_data.get("CustomerID", -1)
	if ctype == "VIP":
		print("  Discount: %.0f%%" % Database.get_vip_discount(cid))
	elif ctype == "Rude":
		print("  Extra delay: +%d days" % Database.get_rude_delay(cid))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


# when the sewing machine finishes, the order is done
func _on_garment_sewn(_type: String) -> void:
	complete_order()


# ── Movement ──────────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	# walking out — move forward until he's off screen then clean up
	if _leaving:
		velocity = global_transform.basis.z * move_speed
		move_and_slide()
		if global_position.z < -5.0:
			customer_left.emit()
			queue_free()
		return

	# still heading to his spot
	if not _walking:
		return

	velocity = Vector3(0, 0, move_speed)
	move_and_slide()

	# reached the standing position, stop and play idle after a short delay
	if global_position.z >= target_z:
		global_position.z = target_z
		velocity           = Vector3.ZERO
		_walking           = false
		animation_player.play(idle_anim)
		await get_tree().create_timer(label_appear_delay).timeout
		_idle_done = true


func _process(delta: float) -> void:
	# count down the price popup timer and hide it when it expires
	if _show_popup and _price_popup != null and _price_popup.visible:
		_price_timer -= delta
		if _price_timer <= 0.0:
			_price_popup.visible = false
			_show_popup          = false

	if not _idle_done or _player == null or _leaving:
		return

	# show the interact label only when the player is close enough
	var dist: float = global_position.distance_to(_player.global_position)
	interaction_label.visible = (
		dist <= interact_distance
		and not (_order_canvas != null and _order_canvas.visible)
		and not _order_pending
	)

	if interaction_label.visible and Input.is_action_just_pressed("interact"):
		_open_order_ui()


func _start_leaving() -> void:
	# turn around and walk out
	interaction_label.visible = false
	_leaving = true
	animation_player.play("Walk_Formal")
	_set_collision(false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", rotation.y - PI, 1.2)


# toggle all collision shapes on or off
func _set_collision(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled


# ── Order UI ──────────────────────────────────────────────────────────────────

func _open_order_ui() -> void:
	interaction_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# only generate the order once — reuse it if the player closes and reopens
	if not _order_generated:
		_current_order   = Database.generate_random_dress_order(_customer_name)
		_order_generated = true
		print("Order generated for %s: " % _customer_name, _current_order)

	# fill in the customer header
	_cust_name_lbl.text = "👤   " + _customer_name
	var ctype: String = _customer_data.get("customer_type", "Normal")
	var cid:   int    = _customer_data.get("CustomerID", -1)
	match ctype:
		"VIP":
			_cust_type_lbl.text = "⭐ VIP — %.0f%% discount" % Database.get_vip_discount(cid)
			_cust_type_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		"Rude":
			_cust_type_lbl.text = "⚠ Rude — +%d day delay" % Database.get_rude_delay(cid)
			_cust_type_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_:
			_cust_type_lbl.text = "Normal"
			_cust_type_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))

	# clear whatever was in the list before and rebuild it fresh
	for child in _dress_list_vbox.get_children():
		child.queue_free()

	var dresses: Array = _current_order.get("dresses", [])
	for i in range(dresses.size()):
		var d: Dictionary = dresses[i]
		var parts: Array  = d.get("parts", [])

		# bold gold label for each dress
		var dress_hdr := Label.new()
		dress_hdr.text = "  DRESS %d  —  %s" % [i + 1, d.get("dress", "—")]
		dress_hdr.add_theme_font_size_override("font_size", 18)
		dress_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		_dress_list_vbox.add_child(dress_hdr)

		# PART / FABRIC / COLOR column headers
		var col_hdr := HBoxContainer.new()
		col_hdr.add_theme_constant_override("separation", 4)
		_dress_list_vbox.add_child(col_hdr)
		for col_text in ["    PART", "FABRIC", "COLOR"]:
			var h := Label.new()
			h.text = col_text
			h.add_theme_font_size_override("font_size", 13)
			h.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col_hdr.add_child(h)

		_dress_list_vbox.add_child(HSeparator.new())

		# one row per dress part with its fabric and colour
		for p in parts:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)

			var part_lbl := Label.new()
			part_lbl.text                  = "    " + p.get("part_name", "Part")
			part_lbl.add_theme_font_size_override("font_size", 16)
			part_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
			part_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(part_lbl)

			var fab_lbl := Label.new()
			fab_lbl.text                  = p.get("fabric", "—")
			fab_lbl.add_theme_font_size_override("font_size", 16)
			fab_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
			fab_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(fab_lbl)

			var col_lbl := Label.new()
			col_lbl.text                  = p.get("color", "—")
			col_lbl.add_theme_font_size_override("font_size", 16)
			col_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
			col_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col_lbl)

			_dress_list_vbox.add_child(row)

		# separator between dresses but not after the last one
		if i < dresses.size() - 1:
			var sp := HSeparator.new()
			sp.add_theme_constant_override("separation", 6)
			_dress_list_vbox.add_child(sp)

	# re-enable in case it was disabled from a previous accept
	if _custom_accept_btn != null:
		_custom_accept_btn.disabled = false

	_order_canvas.visible = true


func _close_order_ui() -> void:
	if _order_canvas != null:
		_order_canvas.visible = false
	order_ui.visible = false
	# give mouse back to the game
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Accept order ──────────────────────────────────────────────────────────────

func _accept_order() -> void:
	# prevent double-clicking the button
	if _custom_accept_btn != null:
		_custom_accept_btn.disabled = true

	_order_pending              = true
	_current_order["status"]    = "pending"
	_current_order["timestamp"] = Time.get_datetime_string_from_system()

	var cid: int = _customer_data.get("CustomerID", -1)
	if cid != -1:
		# write the order to the DB and attach all the dress details
		var oid: int = Database.create_order_record(cid)
		_current_order["db_order_id"] = oid
		Database.attach_all_dresses_to_order(oid, _current_order)

		# calculate the real price and show the popup
		var derived_price: float = Database.calculate_order_price(oid)
		_current_order["coin_reward"] = int(derived_price)
		_show_price_popup(derived_price)

	print("Order accepted & stored: ", _current_order)
	_close_order_ui()
	GameManager.receive_order(_current_order)
	_start_leaving()


# show the coin total for a few seconds then auto-hide
func _show_price_popup(price: float) -> void:
	if _price_label == null:
		return
	_price_label.text    = "Total Price: %d coins" % int(price)
	_price_popup.visible = true
	_show_popup          = true
	_price_timer         = 3.5


# called when the order is fully sewn and dispatched
func complete_order() -> void:
	_order_pending   = false
	_order_generated = false
	_current_order   = {}
	print("Berserk customer: order fully completed.")


func _save_order_to_database(_order: Dictionary) -> void:
	pass
