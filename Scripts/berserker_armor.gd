# berserkarmor.gd
extends CharacterBody3D

@onready var animation_player: AnimationPlayer = $UAL1_Standard/AnimationPlayer
@onready var interaction_label: Label3D = $InteractionLabel
@onready var order_ui: Panel = $CanvasLayer/OrderUI
@onready var close_btn: Button = $CanvasLayer/OrderUI/CloseButton
@onready var accept_btn: Button = $CanvasLayer/OrderUI/AcceptButton

# --- Movement Settings ---
@export var move_speed: float = 1.50
@export var target_z: float = 10.0
@export var walk_anim: String = "Walk"
@export var idle_anim: String = "idle_2/mixamo_com"

# --- Interaction Settings ---
@export var interact_distance: float = 3.0
@export var label_appear_delay: float = 1.0

# ── DB-resolved customer data (populated in _ready via Database) ───────────────
var _customer_data: Dictionary = {}   # all columns + "customer_type"
var _customer_name: String     = ""   # resolved name for this visit

# --- Randomization Pools (still used for order dresses / fabric) ---
var dress_pool: Array = [
	"T-Shirt", "Frock", "Bishop Gown", "Pants", "Jacket", "Maxi", "Lehenga"
]
var fabric_pool: Array = [
	"Cotton", "Silk", "Linen", "Polyester", "Lawn", "Chiffon", "Denim"
]
var color_pool: Array = [
	"Navy Blue", "Crimson Red", "Forest Green", "Pearl White",
	"Jet Black", "Purple", "Golden", "Sky Blue"
]
var fabric_used_pool: Array = [
	"2.5 meters", "3.0 meters", "3.5 meters", "4.0 meters",
	"4.5 meters", "5.0 meters", "5.5 meters"
]

# --- XP / Coin ranges per dress count ---
var xp_ranges: Dictionary   = { 1: [50, 120],  2: [130, 250], 3: [260, 400] }
var coin_ranges: Dictionary = { 1: [100, 300], 2: [320, 550], 3: [570, 900] }

# --- Internal ---
var _walking: bool           = true
var _idle_done: bool         = false
var _player: Node3D          = null
var _order_pending: bool     = false
var _order_generated: bool   = false
var _current_order: Dictionary = {}


func _ready() -> void:
	interaction_label.visible = false
	order_ui.visible = false
	animation_player.play(walk_anim)
	_player = get_tree().get_first_node_in_group("player")

	close_btn.pressed.connect(_close_order_ui)
	accept_btn.pressed.connect(_accept_order)
	GameManager.garment_sewn.connect(_on_garment_sewn)

	# ── Pick a random name then resolve/create in DB ──────────────────────────
	# Step 1: name only from pool
	_customer_name = Database.get_random_name()

	# Step 2: DB checks — if new, generate measurements etc. from arrays there
	# (Database.get_or_create_customer handles the "name exists?" branching)
	_customer_data = Database.get_or_create_customer(_customer_name)

	# Use the name from DB record in case it was formatted differently
	_customer_name = _customer_data.get("Name", _customer_name)

	_print_customer_info()


func _print_customer_info() -> void:
	var ctype: String = _customer_data.get("customer_type", "Normal")
	print("━━━ Customer Arrived ━━━")
	print("  Name:   ", _customer_name, "  [", ctype, "]")
	print("  City:   ", _customer_data.get("City", "?"))
	print("  Chest:  ", _customer_data.get("Chest", "?"), "\"  Waist: ", _customer_data.get("Waist", "?"), "\"")
	if ctype == "VIP":
		print("  Discount: %.0f%%" % Database.get_vip_discount(_customer_data.get("CustomerID", -1)))
	elif ctype == "Rude":
		print("  Extra delay: +%d days" % Database.get_rude_delay(_customer_data.get("CustomerID", -1)))
	print("━━━━━━━━━━━━━━━━━━━━━━━━")


func _on_garment_sewn(_type: String) -> void:
	complete_order()


func _physics_process(delta: float) -> void:
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
	if not _idle_done or _player == null:
		return

	var dist: float = global_position.distance_to(_player.global_position)

	interaction_label.visible = (
		dist <= interact_distance
		and not order_ui.visible
		and not _order_pending
	)

	if interaction_label.visible and Input.is_action_just_pressed("interact"):
		_open_order_ui()


func _open_order_ui() -> void:
	interaction_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not _order_generated:
		_current_order   = _generate_random_order()
		_order_generated = true
		print("Order generated for %s: " % _customer_name, _current_order)

	# --- Populate UI ---
	order_ui.get_node("CustomerName").text = _customer_name

	# Show customer type badge if VIP or Rude
	var ctype: String = _customer_data.get("customer_type", "Normal")
	if order_ui.has_node("CustomerType"):
		var type_lbl: Label = order_ui.get_node("CustomerType")
		match ctype:
			"VIP":
				type_lbl.text           = "⭐ VIP — %.0f%% discount" \
										  % Database.get_vip_discount(_customer_data.get("CustomerID", -1))
				type_lbl.modulate       = Color(1.0, 0.85, 0.2)
			"Rude":
				type_lbl.text           = "⚠ Rude — +%d day delay" \
										  % Database.get_rude_delay(_customer_data.get("CustomerID", -1))
				type_lbl.modulate       = Color(1.0, 0.35, 0.35)
			_:
				type_lbl.text           = "Normal"
				type_lbl.modulate       = Color(0.85, 0.85, 0.85)

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


func _generate_random_order() -> Dictionary:
	var num_dresses: int = randi_range(1, 3)
	var dresses: Array   = []

	for i in range(num_dresses):
		dresses.append({
			"dress":  dress_pool[randi() % dress_pool.size()],
			"fabric": fabric_pool[randi() % fabric_pool.size()],
			"color":  color_pool[randi() % color_pool.size()],
		})

	var xp_range:   Array = xp_ranges[num_dresses]
	var coin_range: Array = coin_ranges[num_dresses]

	var xp:    int = randi_range(xp_range[0],   xp_range[1])
	var coins: int = randi_range(coin_range[0],  coin_range[1])

	return {
		"customer_name": _customer_name,
		"dresses":       dresses,
		"fabric_used":   fabric_used_pool[randi() % fabric_used_pool.size()],
		"xp_reward":     xp,
		"coin_reward":   coins,
		"timestamp":     Time.get_datetime_string_from_system(),
		"status":        "pending"
	}


func _close_order_ui() -> void:
	order_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _accept_order() -> void:
	_order_pending           = true
	_current_order["status"] = "pending"
	_current_order["timestamp"] = Time.get_datetime_string_from_system()

	# ── DB: Create the Order record right now ─────────────────────────────────
	var cid: int = _customer_data.get("CustomerID", -1)
	if cid != -1:
		var oid: int = Database.create_order_record(cid)
		_current_order["db_order_id"] = oid   # carry it with the order dict

	print("Order accepted: ", _current_order)
	_close_order_ui()
	GameManager.receive_order(_current_order)


func complete_order() -> void:
	_order_pending   = false
	_order_generated = false
	_current_order   = {}

	# Next visit: pick a fresh name and (re)resolve in DB
	_customer_name = Database.get_random_name()
	_customer_data = Database.get_or_create_customer(_customer_name)
	_customer_name = _customer_data.get("Name", _customer_name)

	print("Order completed! Customer ready for a new order.")


func _save_order_to_database(_order: Dictionary) -> void:
	# Database.create_order_record() is now called inside _accept_order().
	# This stub is kept so nothing breaks if it's called from elsewhere.
	pass
