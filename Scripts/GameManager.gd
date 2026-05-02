extends Node
 
signal order_received(order_data)
signal garment_cut(garment_type)
signal garment_sewn(garment_type)
 
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
 
 
func receive_order(order):
	current_order = {
		"type":    order["dresses"][0]["dress"].to_lower().replace(" ", "_"),  # e.g. "t_shirt"
		"status":  "pending_cut",
		"full":    order   # keep the full order for XP/coins later
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

	# ── Pay out XP and coins ──────────────────────────────────
	var full = current_order.get("full", {})
	var xp:    int = full.get("xp_reward",   0)
	var coins: int = full.get("coin_reward",  0)
	print("Order complete! Rewarding XP: %d  Coins: %d" % [xp, coins])
	# Hook your player stats here:
	# PlayerStats.add_xp(xp)
	# PlayerStats.add_coins(coins)

	current_state = GameState.FREE_ROAM
