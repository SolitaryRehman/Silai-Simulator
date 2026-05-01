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

# --- Order Data ---
@export var customer_name: String = "Customer"

# --- Randomization Pools (edit freely) ---
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

# --- XP ranges per dress count ---
# Format: [min, max]
var xp_ranges: Dictionary = {
	1: [50,  120],
	2: [130, 250],
	3: [260, 400]
}

# --- Coin ranges per dress count ---
var coin_ranges: Dictionary = {
	1: [100, 300],
	2: [320, 550],
	3: [570, 900]
}

# --- Internal ---
var _walking: bool           = true
var _idle_done: bool         = false
var _player: Node3D          = null
var _order_pending: bool     = false   # 🔒 locked after accepting
var _order_generated: bool   = false   # 🔒 locked after first interaction
var _current_order: Dictionary = {}


func _ready() -> void:
	interaction_label.visible = false
	order_ui.visible = false
	animation_player.play(walk_anim)
	_player = get_tree().get_first_node_in_group("player")

	close_btn.pressed.connect(_close_order_ui)
	accept_btn.pressed.connect(_accept_order)


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

	# 🔒 Hide label if order is pending (accepted but not delivered yet)
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

	# 🎲 Generate order ONLY once per customer visit
	# Cancelling and re-opening will show the SAME order
	if not _order_generated:
		_current_order   = _generate_random_order()
		_order_generated = true
		print("Order generated for %s: " % customer_name, _current_order)

	# --- Populate UI with the locked order ---
	order_ui.get_node("CustomerName").text = customer_name

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
	order_ui.get_node("XPReward").text   = "XP: +"    + str(_current_order["xp_reward"])
	order_ui.get_node("CoinReward").text = "Coins: "  + str(_current_order["coin_reward"])

	order_ui.visible = true


# --- Builds a fully random order from pools ---
func _generate_random_order() -> Dictionary:
	var num_dresses: int = randi_range(1, 3)
	var dresses: Array   = []

	for i in range(num_dresses):
		dresses.append({
			"dress":  dress_pool[randi() % dress_pool.size()],
			"fabric": fabric_pool[randi() % fabric_pool.size()],
			"color":  color_pool[randi() % color_pool.size()],
		})

	# 🎲 XP and Coins scale with number of dresses
	var xp_range: Array   = xp_ranges[num_dresses]
	var coin_range: Array = coin_ranges[num_dresses]

	var xp:    int = randi_range(xp_range[0],   xp_range[1])
	var coins: int = randi_range(coin_range[0],  coin_range[1])

	return {
		"customer_name": customer_name,
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
	_order_pending              = true    #  Lock interaction
	_current_order["status"]    = "pending"
	_current_order["timestamp"] = Time.get_datetime_string_from_system()

	print("Order accepted: ", _current_order)
	_save_order_to_database(_current_order)
	_close_order_ui()


# --- Call this from your delivery/crafting script when order is fulfilled ---
func complete_order() -> void:
	_order_pending   = false   #  Unlock interaction
	_order_generated = false   #  Allow a fresh random order next time
	_current_order   = {}
	print("Order completed! Customer ready for a new order.")


func _save_order_to_database(order: Dictionary) -> void:
	# -------------------------------------------------------
	# DATABASE HOOK — connect your backend here
	# -------------------------------------------------------
	# Option A: SQLite
	#   db.insert_row("orders", order)
	#
	# Option B: Firebase / REST API
	#   $HTTPRequest.request("https://yourapi.com/orders",
	#       ["Content-Type: application/json"],
	#       HTTPClient.METHOD_POST,
	#       JSON.stringify(order))
	#
	# Option C: Local JSON file
	#   var f = FileAccess.open("user://orders.json", FileAccess.WRITE)
	#   f.store_string(JSON.stringify(order))
	#   f.close()
	# -------------------------------------------------------
	print("Saving to database: ", order)
