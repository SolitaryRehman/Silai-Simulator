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

# ── Multi-order support ───────────────────────────────────────────────────────
# pending_orders: all accepted orders waiting to be worked on.
#   Key   = db_order_id (int)
#   Value = full order entry dict (same shape as current_order)
var pending_orders: Dictionary = {}

# current_order: the order currently at the cutting/sewing table.
# Set by set_active_order(); cleared when sewing completes.
var current_order: Dictionary = {}

var cut_pieces:   Array = []
var is_piece_cut: bool  = false

# ── HUD mirrors — always in sync with Database ────────────────────────────────
var player_level: int = 1
var player_xp:    int = 0
var player_coins: int = 0


func _ready() -> void:
	# Load persisted player stats from DB the moment the game starts.
	# Database AutoLoad runs before GameManager, so it is safe to call here.
	_sync_stats()
	print("GameManager: Player stats loaded — Level %d | XP %d | Coins %d"
		  % [player_level, player_xp, player_coins])


# ── Called by customer scripts (_accept_order) ────────────────────────────────
func receive_order(order: Dictionary) -> void:
	var db_order_id: int = order.get("db_order_id", -1)

	var order_entry: Dictionary = {
		"type":   order["dresses"][0]["dress"].to_lower().replace(" ", "_"),
		"status": "pending_cut",
		"full":   order   # carries db_order_id, dresses array, xp/coin rewards
	}

	# Add to the queue; multiple orders can sit here simultaneously
	if db_order_id > 0:
		pending_orders[db_order_id] = order_entry

	emit_signal("order_received", order_entry)
	print("GameManager: Order queued (ID=%d, type=%s). Queue size: %d"
		  % [db_order_id, order_entry["type"], pending_orders.size()])


## Moves a pending order into current_order so the cutting table can work on it.
## Returns true on success, false if the order_id is not in the queue.
func set_active_order(db_order_id: int) -> bool:
	if not pending_orders.has(db_order_id):
		push_warning("GameManager: set_active_order — ID %d not in pending_orders." % db_order_id)
		return false
	current_order = pending_orders[db_order_id]
	cut_pieces.clear()
	is_piece_cut = false
	print("GameManager: Order %d is now active at cutting table." % db_order_id)
	return true


## Convenience — picks the lowest-ID pending order automatically.
## Used when only one order is in the queue (most common case).
func set_first_pending_order() -> bool:
	if pending_orders.is_empty():
		return false
	var keys: Array = pending_orders.keys()
	keys.sort()
	return set_active_order(keys[0])


func complete_cutting() -> void:
	is_piece_cut = true
	current_order["status"] = "pending_sew"

	# Update DB status to 'Sewing'
	var order_id: int = current_order.get("full", {}).get("db_order_id", -1)
	if order_id > 0:
		Database.update_order_status(order_id, "Sewing")

	emit_signal("garment_cut", current_order["type"])


func complete_sewing() -> void:
	current_order["status"] = "complete"
	emit_signal("garment_sewn", current_order["type"])

	var full:     Dictionary = current_order.get("full", {})
	var xp:       int        = full.get("xp_reward",   0)
	var coins:    int        = full.get("coin_reward",  0)
	var order_id: int        = full.get("db_order_id", -1)

	# Remove from pending queue
	if order_id > 0 and pending_orders.has(order_id):
		pending_orders.erase(order_id)

	# Finalize in DB (computes Total_price, sets Order_status = 'Completed')
	if order_id > 0:
		Database.finalize_order(order_id)

	# Reward player (trigger handles level-up automatically)
	if xp > 0 or coins > 0:
		Database.add_player_rewards(xp, coins)

	# Refresh HUD mirrors from DB
	_sync_stats()

	var pd: Dictionary = Database.get_player_data()
	print("═══ Order Complete! ═══")
	print("  XP: +%d  |  Coins: +%d" % [xp, coins])
	print("  Player → Level %d  |  XP %d  |  Coins %d"
		  % [pd.get("Level", 1), pd.get("Current_xp", 0), pd.get("Coins", 0)])
	print("  Total earnings so far: %.2f coins" % Database.get_total_earnings())
	print("  Orders still pending:  %d" % pending_orders.size())
	print("════════════════════════")

	current_order = {}
	current_state = GameState.FREE_ROAM


# ─────────────────────────────────────────────────────────────────────────────
# Pulls latest Level / XP / Coins from DB and notifies HUD via stats_changed
# ─────────────────────────────────────────────────────────────────────────────
func _sync_stats() -> void:
	var data: Dictionary = Database.get_player_data()
	player_level = data.get("Level",      1)
	player_xp    = data.get("Current_xp", 0)
	player_coins = data.get("Coins",      0)
	emit_signal("stats_changed")
