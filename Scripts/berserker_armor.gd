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
@export var dresses: Array[Dictionary] = [
	{"dress": "T-Shirt", "fabric": "Cotton", "color": "Navy Blue"},
	{"dress": "Frock",   "fabric": "Silk",   "color": "Crimson Red"},
]
@export var fabric_used: String = "4.5 meters"
@export var xp_reward: int      = 120
@export var coin_reward: int    = 350

# --- Internal ---
var _walking: bool   = true
var _idle_done: bool = false
var _player: Node3D  = null


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
	interaction_label.visible = dist <= interact_distance and not order_ui.visible

	if interaction_label.visible and Input.is_action_just_pressed("interact"):
		_open_order_ui()


func _open_order_ui() -> void:
	interaction_label.visible = false

	# --- unlock mouse ---
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	order_ui.get_node("CustomerName").text = customer_name

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

	order_ui.get_node("FabricUsed").text = fabric_used
	order_ui.get_node("XPReward").text   = "XP: +"   + str(xp_reward)
	order_ui.get_node("CoinReward").text = "Coins: " + str(coin_reward)

	order_ui.visible = true


func _close_order_ui() -> void:
	order_ui.visible = false
	# --- lock mouse back ---
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _accept_order() -> void:
	# --- Build order dictionary (ready for database) ---
	var order: Dictionary = {
		"customer_name": customer_name,
		"dresses":       dresses,
		"fabric_used":   fabric_used,
		"xp_reward":     xp_reward,
		"coin_reward":   coin_reward,
		"timestamp":     Time.get_datetime_string_from_system(),
		"status":        "pending"
	}

	# --- Send to database (plug in your method here) ---
	_save_order_to_database(order)

	_close_order_ui()


func _save_order_to_database(order: Dictionary) -> void:
	# -------------------------------------------------------
	# DATABASE HOOK — connect your backend here
	# -------------------------------------------------------
	# Option A: SQLite (gdnative sqlite plugin)
	#   db.insert_row("orders", order)
	#
	# Option B: Firebase / REST API
	#   $HTTPRequest.request("https://yourapi.com/orders",
	#       ["Content-Type: application/json"],
	#       HTTPClient.METHOD_POST,
	#       JSON.stringify(order))
	#
	# Option C: Save to file (local JSON for now)
	#   var f = FileAccess.open("user://orders.json", FileAccess.WRITE)
	#   f.store_string(JSON.stringify(order))
	#   f.close()
	# -------------------------------------------------------

	print("Order accepted: ", order)   # placeholder until DB is connected
