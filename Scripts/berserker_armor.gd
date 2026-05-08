# berserk_armor.gd
extends CharacterBody3D

@onready var animation_player: AnimationPlayer = $armor/GeneralSkeleton/AnimationPlayer
@onready var interaction_label: Label3D = $InteractionLabel
@onready var order_ui: Panel = $CanvasLayer/OrderUI
@onready var close_button: Button = $CanvasLayer/OrderUI/CloseButton
@onready var accept_button: Button = $CanvasLayer/OrderUI/AcceptButton

# --- Movement Settings ---
@export var move_speed: float = 1.50
@export var target_z: float = 10.0
@export var idle_anim: String = "idle_2/mixamo_com"

# --- Interaction Settings ---
@export var interact_distance: float = 2.0
@export var label_appear_delay: float = 1.0

# ── DB-resolved customer data ──────────────────────────────────────────────────
var _customer_data: Dictionary = {}
var _customer_name: String     = ""

# --- XP / Coin ranges kept for UI reference only (actual values come from DB.generate_random_dress_order) ---
# (pools removed — now live in Database as constants)

# --- Internal ---
var _walking: bool             = true
var _idle_done: bool           = false
var _player: Node3D            = null
var _order_pending: bool       = false
var _order_generated: bool     = false
var _current_order: Dictionary = {}
var _leaving: bool             = false

signal customer_left


func _ready() -> void:
	interaction_label.visible = false
	order_ui.visible          = false
	animation_player.play("Walk_Formal")
	_player = get_tree().get_first_node_in_group("player")

	close_button.pressed.connect(_close_order_ui)
	accept_button.pressed.connect(_accept_order)
	GameManager.garment_sewn.connect(_on_garment_sewn)

	_customer_name = Database.get_random_name()
	_customer_data = Database.get_or_create_customer(_customer_name)
	_customer_name = _customer_data.get("Name", _customer_name)

	_print_customer_info()

	_set_collision(false)
	await get_tree().create_timer(2.5).timeout
	_set_collision(true)


func _print_customer_info() -> void:
	var ctype: String = _customer_data.get("customer_type", "Normal")
	print("━━━ Customer Arrived ━━━")
	print("  Name:   ", _customer_name, "  [", ctype, "]")
	print("  City:   ", _customer_data.get("City", "?"))
	print("  Chest:  ", _customer_data.get("Chest", "?"), "\"  Waist: ", _customer_data.get("Waist", "?"), "\"")
	var cid: int = _customer_data.get("CustomerID", -1)
	if ctype == "VIP":
		print("  Discount: %.0f%%" % Database.get_vip_discount(cid))
	elif ctype == "Rude":
		print("  Extra delay: +%d days" % Database.get_rude_delay(cid))
	print("━━━━━━━━━━━━━━━━━━━━━━━━")


func _on_garment_sewn(_type: String) -> void:
	complete_order()


func _physics_process(_delta: float) -> void:
	if _leaving:
		velocity = global_transform.basis.z * move_speed
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
		animation_player.play(idle_anim)
		await get_tree().create_timer(label_appear_delay).timeout
		_idle_done = true


func _process(_delta: float) -> void:
	if not _idle_done or _player == null or _leaving:
		return

	var dist: float = global_position.distance_to(_player.global_position)

	interaction_label.visible = (
		dist <= interact_distance
		and not order_ui.visible
		and not _order_pending
	)

	if interaction_label.visible and Input.is_action_just_pressed("interact"):
		_open_order_ui()


func _start_leaving() -> void:
	interaction_label.visible = false
	_leaving = true
	animation_player.play("Walk_Formal")
	_set_collision(false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", rotation.y - PI, 1.2)


func _set_collision(enabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled


func _open_order_ui() -> void:
	interaction_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not _order_generated:
		# ── All randomization now done in database.gd (single source of truth) ──
		_current_order   = Database.generate_random_dress_order(_customer_name)
		_order_generated = true
		print("Order generated for %s: " % _customer_name, _current_order)

	order_ui.get_node("CustomerName").text = _customer_name

	var ctype: String = _customer_data.get("customer_type", "Normal")
	var cid:   int    = _customer_data.get("CustomerID", -1)
	if order_ui.has_node("CustomerType"):
		var type_lbl: Label = order_ui.get_node("CustomerType")
		match ctype:
			"VIP":
				type_lbl.text     = "⭐ VIP — %.0f%% discount" % Database.get_vip_discount(cid)
				type_lbl.modulate = Color(1.0, 0.85, 0.2)
			"Rude":
				type_lbl.text     = "⚠ Rude — +%d day delay" % Database.get_rude_delay(cid)
				type_lbl.modulate = Color(1.0, 0.35, 0.35)
			_:
				type_lbl.text     = "Normal"
				type_lbl.modulate = Color(0.85, 0.85, 0.85)

	var dresses: Array = _current_order["dresses"]
	for i in range(1, 4):
		var slot: Control = order_ui.get_node("Slot%d" % i)
		if i - 1 < dresses.size():
			var d: Dictionary = dresses[i - 1]
			slot.visible = true
			slot.get_node("Number").text    = "%d." % i
			slot.get_node("DressName").text = d.get("dress",  "—")
			slot.get_node("Fabric").text    = d.get("fabric", "—")
			slot.get_node("Color").text     = d.get("color",  "—")
		else:
			slot.visible = false

	order_ui.get_node("FabricUsed").text = _current_order["fabric_used"]
	order_ui.get_node("XPReward").text   = "XP: +"   + str(_current_order["xp_reward"])
	order_ui.get_node("CoinReward").text = "Coins: " + str(_current_order["coin_reward"])

	order_ui.visible = true


func _close_order_ui() -> void:
	order_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _accept_order() -> void:
	_order_pending              = true
	_current_order["status"]    = "pending"
	_current_order["timestamp"] = Time.get_datetime_string_from_system()

	var cid: int = _customer_data.get("CustomerID", -1)
	if cid != -1:
		var oid: int = Database.create_order_record(cid)
		_current_order["db_order_id"] = oid
		Database.attach_all_dresses_to_order(oid, _current_order)

	print("Order accepted & stored: ", _current_order)
	_close_order_ui()
	GameManager.receive_order(_current_order)
	_start_leaving()


func complete_order() -> void:
	_order_pending   = false
	_order_generated = false
	_current_order   = {}
	print("Order completed! Customer ready for a new order.")


func _save_order_to_database(_order: Dictionary) -> void:
	pass
