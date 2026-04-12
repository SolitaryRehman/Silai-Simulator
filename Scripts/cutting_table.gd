extends Area3D
 
# ─────────────────────────────────────────────
#  Node references
#  Adjust the paths if your scene tree differs
# ─────────────────────────────────────────────
@onready var cutting_minigame: CanvasLayer = $"../CuttingMinigame"
@onready var prompt_label: Label3D = $PromptLabel
 
var player_ref: CharacterBody3D = null
 
 
func _ready():
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	#---------------------------------------------------------temp
	print("CuttingTable ready!")
	print("CuttingMinigame found: ", cutting_minigame)
 
 
func _process(_delta):
	if player_ref == null:
		return
 
	if Input.is_action_just_pressed("interact"):
		
		print("E pressed!")
		print("Order: ", GameManager.current_order)
		print("Status: ", GameManager.current_order.get("status"))
		
		if GameManager.current_order.is_empty():
			print("No active order!")
			return
		if GameManager.current_order.get("status") == "pending_cut":
			_start_cutting()
 
 
func _start_cutting():
	GameManager.current_state = GameManager.GameState.CUTTING
	player_ref.lock_for_minigame()
	prompt_label.visible = false
 
	# Connect signals only once
	if not cutting_minigame.cutting_complete.is_connected(_on_cutting_complete):
		cutting_minigame.cutting_complete.connect(_on_cutting_complete)
	if not cutting_minigame.cutting_cancelled.is_connected(_on_cutting_cancelled):
		cutting_minigame.cutting_cancelled.connect(_on_cutting_cancelled)
 
	cutting_minigame.start_minigame(GameManager.current_order["type"])
 
 
# Cutting done — let player walk to sewing table
func _on_cutting_complete():
	player_ref.in_minigame = false
	player_ref.can_move = true
	player_ref.can_jump = true
	player_ref.capture_mouse()
 
 
# Player pressed ESC — cancel and restore
func _on_cutting_cancelled():
	player_ref.unlock_from_minigame()
	if player_ref != null:
		prompt_label.visible = true
 
 
func _on_body_entered(body):
	
	print("Something entered: ", body.name)
	print("Is in player group: ", body.is_in_group("player"))
	
	if body.is_in_group("player"):
		player_ref = body
		if not GameManager.current_order.is_empty():
			prompt_label.visible = true
 
 
func _on_body_exited(body):
	if body.is_in_group("player"):
		player_ref = null
		prompt_label.visible = false
