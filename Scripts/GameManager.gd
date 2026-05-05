# gamemanager.gd
extends Node

signal order_received(order_data)
signal garment_cut(garment_type)
signal garment_sewn(garment_type)
signal stats_changed

enum GameState {
	FREE_ROAM,
	CUTTING,
	SEWING,
	DELIVERING
}

var current_state: GameState = GameState.FREE_ROAM
var current_order: Dictionary = {}
var cut_pieces: Array = []
var is_piece_cut: bool = false

# ── HUD mirror — always in sync with Database ─────────────────────────────────
var player_level: int = 1
var player_xp:    int = 0
var player_coins: int = 0


func receive_order(order):
	current_order = {
		"type":   order["dresses"][0]["dress"].to_lower().replace(" ", "_"),
		"status": "pending_cut",
		"full":   order
	}
	cut_pieces.clear()
	is_piece_cut = false
	emit_signal("order_received", current_order)
	print("New order received: ", current_order["type"])


func complete_cutting():
	is_piece_cut = true
	current_order["status"] = "pending_sew"
	emit_signal("garment_cut", current_order["type"])


func complete_sewing():
	current_order["status"] = "complete"
	emit_signal("garment_sewn", current_order["type"])

	var full: Dictionary = current_order.get("full", {})
	var xp:    int = full.get("xp_reward",  0)
	var coins: int = full.get("coin_reward", 0)

	# ── DB: Finalize order (computes Total_price via SQL, marks Completed) ────
	var order_id: int = full.get("db_order_id", Database.active_order_id)
	if order_id > 0:
		Database.finalize_order(order_id)

	# ── DB: Add XP and coins to Player (trigger handles level-up) ────────────
	if xp > 0 or coins > 0:
		Database.add_player_rewards(xp, coins)

# ── Pull fresh values from DB into the HUD mirrors ────────────────────────
	_sync_stats()

	# Log to console for verification during demo
	var player_data: Dictionary = Database.get_player_data()
	print("═══ Order Complete! ═══")
	print("  XP awarded: +%d  |  Coins: +%d" % [xp, coins])
	print("  Player → Level %d  |  XP: %d  |  Coins: %d"
		  % [player_data.get("Level", 1), player_data.get("Current_xp", 0), player_data.get("Coins", 0)])
	print("  Total earnings so far: %.2f coins" % Database.get_total_earnings())
	print("════════════════════════")

	current_state = GameState.FREE_ROAM

# ─────────────────────────────────────────────────────────────────────────────
# Pulls latest Level / XP / Coins from the DB and notifies the HUD
# ─────────────────────────────────────────────────────────────────────────────
func _sync_stats() -> void:
	var data: Dictionary = Database.get_player_data()
	player_level = data.get("Level",      1)
	player_xp    = data.get("Current_xp", 0)
	player_coins = data.get("Coins",      0)
	emit_signal("stats_changed")
