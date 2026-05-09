# girl_1.gd
extends CharacterBody3D

@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer
@onready var interaction_label: Label3D        = $InteractionLabel
@onready var order_ui: Panel                   = $CanvasLayer/OrderUI
@onready var close_button: Button              = $CanvasLayer/OrderUI/CloseButton
@onready var accept_button: Button             = $CanvasLayer/OrderUI/AcceptButton

@export var move_speed:        float   = 0.50
@export var target_z:          float   = 2.25
@export var enter_anim:        String  = "girl_1_start"
@export var leave_anim:        String  = "girl_1_end/mixamo_com"
@export var interact_distance: float   = 2.0
@export var label_appear_delay:float   = 1.0
@export var interact_offset:   Vector3 = Vector3(0, 0, 7.3)

var _customer_data: Dictionary = {}
var _customer_name: String     = ""

var _walking:         bool       = true
var _idle_done:       bool       = false
var _player:          Node3D     = null
var _order_pending:   bool       = false
var _order_generated: bool       = false
var _current_order:   Dictionary = {}
var _leaving:         bool       = false

# ── Price popup ───────────────────────────────────────────────────────────────
var _price_popup: Panel = null
var _price_label: Label = null
var _price_timer: float = 0.0
var _show_popup:  bool  = false

# ── Custom order UI ───────────────────────────────────────────────────────────
var _order_canvas:       CanvasLayer   = null
var _dress_list_vbox:    VBoxContainer = null
var _cust_name_lbl:      Label         = null
var _cust_type_lbl:      Label         = null
var _fabric_summary_lbl: Label         = null
var _xp_lbl:             Label         = null
var _coin_lbl:           Label         = null
var _custom_accept_btn:  Button        = null

signal customer_left


func _ready() -> void:
	interaction_label.visible = false
	order_ui.visible          = false
	animation_player.play(enter_anim)
	_player = get_tree().get_first_node_in_group("player")

	# Keep old scene buttons connected so GDScript doesn't error on missing signals
	close_button.pressed.connect(_close_order_ui)
	accept_button.pressed.connect(_accept_order)

	GameManager.garment_sewn.connect(_on_garment_sewn)

	_customer_name = Database.get_random_name()
	_customer_data = Database.get_or_create_customer(_customer_name)
	_customer_name = _customer_data.get("Name", _customer_name)

	_print_customer_info()
	_build_price_popup()
	_build_order_ui()

	_set_collision(false)
	await get_tree().create_timer(2.5).timeout
	_set_collision(true)


# ── Price popup ───────────────────────────────────────────────────────────────
func _build_price_popup() -> void:
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

	var ok_lbl := Label.new()
	ok_lbl.text                 = "✅  Order Accepted!"
	ok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_lbl.add_theme_font_size_override("font_size", 17)
	vbox.add_child(ok_lbl)

	_price_label = Label.new()
	_price_label.text                 = "Total Price: — coins"
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.add_theme_font_size_override("font_size", 22)
	_price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(_price_label)

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
	_order_canvas = CanvasLayer.new()
	_order_canvas.layer        = 10
	_order_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_order_canvas)

	var overlay := ColorRect.new()
	overlay.color        = Color(0.0, 0.0, 0.0, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_order_canvas.add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(720, 580)
	panel.offset_left         = -360
	panel.offset_right        =  360
	panel.offset_top          = -290
	panel.offset_bottom       =  290
	panel.process_mode        = Node.PROCESS_MODE_ALWAYS
	_order_canvas.add_child(panel)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	root.offset_left   =  18
	root.offset_top    =  14
	root.offset_right  = -18
	root.offset_bottom = -14
	panel.add_child(root)

	var title_lbl := Label.new()
	title_lbl.text                 = "✂   ORDER DETAILS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	root.add_child(title_lbl)

	var cust_row := HBoxContainer.new()
	cust_row.add_theme_constant_override("separation", 12)
	root.add_child(cust_row)

	_cust_name_lbl = Label.new()
	_cust_name_lbl.add_theme_font_size_override("font_size", 16)
	_cust_name_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_cust_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cust_row.add_child(_cust_name_lbl)

	_cust_type_lbl = Label.new()
	_cust_type_lbl.add_theme_font_size_override("font_size", 14)
	cust_row.add_child(_cust_type_lbl)

	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	root.add_child(scroll)

	_dress_list_vbox = VBoxContainer.new()
	_dress_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dress_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_dress_list_vbox)

	root.add_child(HSeparator.new())

	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 18)
	root.add_child(summary_row)

	_fabric_summary_lbl = Label.new()
	_fabric_summary_lbl.add_theme_font_size_override("font_size", 13)
	_fabric_summary_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_fabric_summary_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(_fabric_summary_lbl)

	_xp_lbl = Label.new()
	_xp_lbl.add_theme_font_size_override("font_size", 14)
	_xp_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	summary_row.add_child(_xp_lbl)

	_coin_lbl = Label.new()
	_coin_lbl.add_theme_font_size_override("font_size", 14)
	_coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	summary_row.add_child(_coin_lbl)

	root.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	root.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text                = "✕   Close"
	close_btn.custom_minimum_size = Vector2(150, 38)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_order_ui)
	btn_row.add_child(close_btn)

	_custom_accept_btn = Button.new()
	_custom_accept_btn.text                = "✓   Accept Order"
	_custom_accept_btn.custom_minimum_size = Vector2(180, 38)
	_custom_accept_btn.add_theme_font_size_override("font_size", 14)
	_custom_accept_btn.process_mode        = Node.PROCESS_MODE_ALWAYS
	_custom_accept_btn.pressed.connect(_accept_order)
	btn_row.add_child(_custom_accept_btn)

	_order_canvas.visible = false


func _print_customer_info() -> void:
	var ctype: String = _customer_data.get("customer_type", "Normal")
	print("━━━ Customer Arrived (Girl) ━━━")
	print("  Name:  ", _customer_name, "  [", ctype, "]")
	print("  City:  ", _customer_data.get("City", "?"))
	print("  Chest: ", _customer_data.get("Chest","?"), "\"  Waist: ", _customer_data.get("Waist","?"), "\"")
	var cid: int = _customer_data.get("CustomerID", -1)
	if ctype == "VIP":
		print("  Discount: %.0f%%" % Database.get_vip_discount(cid))
	elif ctype == "Rude":
		print("  Extra delay: +%d days" % Database.get_rude_delay(cid))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


func _on_garment_sewn(_type: String) -> void:
	complete_order()


# ── Movement ──────────────────────────────────────────────────────────────────
func _physics_process(_delta: float) -> void:
	if _leaving:
		velocity = Vector3(0, 0, -move_speed)
		move_and_slide()
		if global_position.z < -5.0:
			customer_left.emit()
			queue_free()
		return

	if not _walking:
		return

	velocity = Vector3(0, 0, move_speed)
	move_and_slide()

	if global_position.z >= target_z:
		global_position.z = target_z
		velocity          = Vector3.ZERO
		_walking          = false
		await get_tree().create_timer(label_appear_delay).timeout
		_idle_done = true


func _process(delta: float) -> void:
	if _show_popup and _price_popup != null and _price_popup.visible:
		_price_timer -= delta
		if _price_timer <= 0.0:
			_price_popup.visible = false
			_show_popup          = false

	if not _idle_done or _player == null or _leaving:
		return

	var check_pos: Vector3 = global_position + interact_offset
	var dist: float        = check_pos.distance_to(_player.global_position)

	interaction_label.visible = (
		dist <= interact_distance
		and not (_order_canvas != null and _order_canvas.visible)
		and not _order_pending
	)

	if interaction_label.visible and Input.is_action_just_pressed("interact"):
		_open_order_ui()


func _start_leaving() -> void:
	interaction_label.visible = false
	_leaving = true
	animation_player.play(leave_anim)
	_set_collision(false)


func _set_collision(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled


# ── Order UI ──────────────────────────────────────────────────────────────────
func _open_order_ui() -> void:
	interaction_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not _order_generated:
		_current_order   = Database.generate_random_dress_order(_customer_name)
		_order_generated = true
		print("Order generated for %s: " % _customer_name, _current_order)

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

	for child in _dress_list_vbox.get_children():
		child.queue_free()

	var dresses: Array = _current_order.get("dresses", [])
	for i in range(dresses.size()):
		var d: Dictionary = dresses[i]
		var parts: Array  = d.get("parts", [])

		var dress_hdr := Label.new()
		dress_hdr.text = "  DRESS %d  —  %s" % [i + 1, d.get("dress", "—")]
		dress_hdr.add_theme_font_size_override("font_size", 15)
		dress_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		_dress_list_vbox.add_child(dress_hdr)

		var col_hdr := HBoxContainer.new()
		col_hdr.add_theme_constant_override("separation", 4)
		_dress_list_vbox.add_child(col_hdr)
		for col_text in ["    PART", "FABRIC", "COLOR"]:
			var h := Label.new()
			h.text = col_text
			h.add_theme_font_size_override("font_size", 11)
			h.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col_hdr.add_child(h)

		_dress_list_vbox.add_child(HSeparator.new())

		for p in parts:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)

			var part_lbl := Label.new()
			part_lbl.text                  = "    " + p.get("part_name", "Part")
			part_lbl.add_theme_font_size_override("font_size", 13)
			part_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
			part_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(part_lbl)

			var fab_lbl := Label.new()
			fab_lbl.text                  = p.get("fabric", "—")
			fab_lbl.add_theme_font_size_override("font_size", 13)
			fab_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
			fab_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(fab_lbl)

			var col_lbl := Label.new()
			col_lbl.text                  = p.get("color", "—")
			col_lbl.add_theme_font_size_override("font_size", 13)
			col_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
			col_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(col_lbl)

			_dress_list_vbox.add_child(row)

		if i < dresses.size() - 1:
			var sp := HSeparator.new()
			sp.add_theme_constant_override("separation", 6)
			_dress_list_vbox.add_child(sp)

	_fabric_summary_lbl.text = "📦  " + _current_order.get("fabric_used", "—")
	_xp_lbl.text             = "✨  XP: +" + str(_current_order.get("xp_reward", 0))
	_coin_lbl.text           = "🪙  ~" + str(_current_order.get("coin_reward", 0))

	if _custom_accept_btn != null:
		_custom_accept_btn.disabled = false

	_order_canvas.visible = true


func _close_order_ui() -> void:
	if _order_canvas != null:
		_order_canvas.visible = false
	order_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Accept order ──────────────────────────────────────────────────────────────
func _accept_order() -> void:
	if _custom_accept_btn != null:
		_custom_accept_btn.disabled = true

	_order_pending              = true
	_current_order["status"]    = "pending"
	_current_order["timestamp"] = Time.get_datetime_string_from_system()

	var cid: int = _customer_data.get("CustomerID", -1)
	if cid != -1:
		var oid: int = Database.create_order_record(cid)
		_current_order["db_order_id"] = oid

		Database.attach_all_dresses_to_order(oid, _current_order)

		var derived_price: float = Database.calculate_order_price(oid)
		_current_order["coin_reward"] = int(derived_price)

		if _coin_lbl != null:
			_coin_lbl.text = "🪙  " + str(int(derived_price)) + " (at dispatch)"

		_show_price_popup(derived_price)

	print("Order accepted & stored (Girl): ", _current_order)
	_close_order_ui()
	GameManager.receive_order(_current_order)
	_start_leaving()


func _show_price_popup(price: float) -> void:
	if _price_label == null:
		return
	_price_label.text    = "Total Price: %d coins" % int(price)
	_price_popup.visible = true
	_show_popup          = true
	_price_timer         = 3.5


func complete_order() -> void:
	_order_pending   = false
	_order_generated = false
	_current_order   = {}
	print("Girl customer: order fully completed.")


func _save_order_to_database(_order: Dictionary) -> void:
	pass
