extends CharacterBody3D


@onready var animation_player: AnimationPlayer = $UAL1_Standard/AnimationPlayer
@onready var interaction_label: Label3D = $InteractionLabel
@onready var order_ui: Panel = $CanvasLayer/OrderUI

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
	{"dress": "Shalwar Kameez", "fabric": "Cotton",  "color": "Navy Blue",   "measurements": "Chest: 38, Length: 42"},
	{"dress": "Lehenga",        "fabric": "Silk",     "color": "Crimson Red", "measurements": "Waist: 30, Length: 44"},
]
@export var fabric_used: String = "4.5 meters"
@export var xp_reward: int      = 120
@export var coin_reward: int    = 350

# --- Internal ---
var _walking: bool    = true
var _idle_done: bool  = false
var _player: Node3D   = null



func _ready() -> void:
	interaction_label.visible = false
	order_ui.visible       = false
	animation_player.play(walk_anim)
	_player = get_tree().get_first_node_in_group("player")


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
	elif order_ui.visible and Input.is_action_just_pressed("interact"):
		order_ui.visible = false


func _open_order_ui() -> void:
	interaction_label.visible = false

	order_ui.get_node("CustomerName").text = customer_name

	for i in range(1, 4):
		var slot: Control = order_ui.get_node("Slot%d" % i)
		if i - 1 < dresses.size():
			var d: Dictionary = dresses[i - 1]
			slot.visible = true
			slot.get_node("Number").text       = "%d." % i
			slot.get_node("DressName").text    = d.get("dress",        "—")
			slot.get_node("Fabric").text       = d.get("fabric",       "—")
			slot.get_node("Color").text        = d.get("color",        "—")
			slot.get_node("Measurements").text = d.get("measurements", "—")
		else:
			slot.visible = false

# CORRECT - full path including Footer
	order_ui.get_node("Footer/FabricUsed").text = "Fabric: "  + fabric_used
	order_ui.get_node("Footer/XpReward").text   = "XP: +"     + str(xp_reward)
	order_ui.get_node("Footer/CoinReward").text = "Coins: "   + str(coin_reward)

	order_ui.visible = true
