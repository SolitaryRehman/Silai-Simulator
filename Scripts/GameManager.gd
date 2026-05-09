# gamemanager.gd
extends Node

signal order_received(order_data)
signal garment_sewn(garment_type)
signal stats_changed

enum GameState {
	FREE_ROAM,
	CUTTING,   # kept for minigame flow — NOT written to DB anymore (CHANGE 1)
	SEWING,    # kept for minigame flow — NOT written to DB anymore (CHANGE 1)
	DELIVERING
}

var current_state: GameState = GameState.FREE_ROAM

# ── Multi-order queue ─────────────────────────────────────────────────────────
# pending_orders: all accepted orders waiting to be worked on.
#   Key   = db_order_id (int)
#   Value = order_entry dict (type, status, full)
var pending_orders: Dictionary = {}

# current_order: order actively being cut/sewn right now.
var current_order: Dictionary = {}

# CHANGE 2: Dress-by-dress tracking within the active order.
# order_dresses is loaded from DB via Database.get_dresses_for_order().
var order_dresses:       Array = []
var current_dress_index: int   = 0

var cut_pieces:   Array = []
var is_piece_cut: bool  = false

# ── HUD mirrors ───────────────────────────────────────────────────────────────
var player_level: int = 1
var player_xp:    int = 0
var player_coins: int = 0


func _ready() -> void:
	# Load player stats from DB (Database AutoLoad runs before GameManager)
	_sync_stats()

	# CHANGE 5: Load any 'Pending' orders that exist in the DB from a previous
	# session so the player can continue working on them without re-accepting.
	_load_pending_orders_from_db()

	print("GameManager: Ready — Level %d | XP %d | Coins %d | Pending orders: %d"
		  % [player_level, player_xp, player_coins, pending_orders.size()])


# ── Called by customer scripts on Accept ──────────────────────────────────────
func receive_order(order: Dictionary) -> void:
	var db_order_id: int = order.get("db_order_id", -1)

	var order_entry: Dictionary = {
		# type = first dress type for quick reference; full list is in order_dresses from DB
		"type":   order["dresses"][0]["dress"].to_lower().replace(" ", "_"),
		"status": "pending_cut",
		"full":   order   # carries db_order_id, dresses, xp/coin rewards
	}

	if db_order_id > 0:
		pending_orders[db_order_id] = order_entry

	emit_signal("order_received", order_entry)
	print("GameManager: Order queued (ID=%d). Queue size: %d"
		  % [db_order_id, pending_orders.size()])


# ── CHANGE 2: Activate a specific pending order for cutting ───────────────────
# Loads the dress list from DB so the cutting table can loop dress-by-dress.
func set_active_order(db_order_id: int) -> bool:
	if not pending_orders.has(db_order_id):
		push_warning("GameManager: set_active_order — ID %d not in queue." % db_order_id)
		return false

	current_order = pending_orders[db_order_id]
	cut_pieces.clear()
	is_piece_cut = false

	# Load dresses from DB — works for both current-session and restored orders
	# Database.get_dresses_for_order() returns: DressID, Dress_type, Colors, Fabrics, Part_count
	order_dresses       = Database.get_dresses_for_order(db_order_id)
	current_dress_index = 0

	print("GameManager: Order %d is now active — %d dress(es) to process."
		  % [db_order_id, order_dresses.size()])
	return true


## Picks the lowest-ID pending order automatically (single-order convenience).
func set_first_pending_order() -> bool:
	if pending_orders.is_empty():
		return false
	var keys: Array = pending_orders.keys()
	keys.sort()
	return set_active_order(keys[0])


# ── CHANGE 1: complete_cutting no longer writes 'Cutting' to DB ───────────────
func complete_cutting() -> void:
	is_piece_cut            = true
	current_order["status"] = "pending_sew"
	# Order stays 'Pending' in DB — no intermediate status written
	emit_signal("garment_sewn", current_order.get("type", "t-shirt"))  # kept for compat


# ── CHANGE 1+2: complete_sewing called only after ALL dresses are done ────────
# Finalizes the order in DB (Pending → Completed), rewards player, clears state.
func complete_sewing() -> void:
	current_order["status"] = "complete"

	var full:     Dictionary = current_order.get("full", {})
	var order_id: int        = full.get("db_order_id", -1)

	if order_id > 0 and pending_orders.has(order_id):
		pending_orders.erase(order_id)

	if order_id > 0:
		Database.finalize_order(order_id)

	_sync_stats()

	print("═══ Order Complete (awaiting dispatch for rewards) ═══")
	print("  Order ID: %d  |  Orders still pending: %d" % [order_id, pending_orders.size()])
	print("═══════════════════════════════════════════════════════")

	current_order       = {}
	order_dresses       = []
	current_dress_index = 0
	current_state       = GameState.FREE_ROAM

	emit_signal("garment_sewn", "complete")


# ── CHANGE 5: Session persistence — restore pending DB orders on startup ──────
# Reads all 'Pending' orders from DB and rebuilds the pending_orders dict
# so the player can continue working on them even after closing the game.
func _load_pending_orders_from_db() -> void:
	# Database.get_pending_orders() → SELECT where Order_status = 'Pending'
	var db_rows: Array = Database.get_pending_orders()
	var loaded: int    = 0

	for row in db_rows:
		var order_id: int = int(row["OrderID"])
		if pending_orders.has(order_id):
			continue   # Already in queue from this session — skip

		# Fetch the dress list for this order from DB
		# Database.get_dresses_for_order() → SELECT Dress JOIN Dress_Parts JOIN Fabric
		var dresses_raw: Array = Database.get_dresses_for_order(order_id)

		# Estimate XP from dress count (original xp_reward not stored in DB)
		var xp_estimate: int = 50 * max(dresses_raw.size(), 1)

		# CHANGE 4: coin_reward = derived price from Dress_Parts × Fabric costs
		# Database.calculate_order_price() runs the correlated-subquery derivation
		var price: float = Database.calculate_order_price(order_id)

		# Build a dresses array compatible with order_entry["full"]["dresses"]
		var dresses_compat: Array = []
		for d in dresses_raw:
			dresses_compat.append({"dress": d.get("Dress_type", "T-Shirt"), "parts": []})

		var order_entry: Dictionary = {
			"type":   dresses_compat[0]["dress"].to_lower().replace(" ", "_") if not dresses_compat.is_empty() else "t-shirt",
			"status": "pending_cut",
			"full": {
				"db_order_id":   order_id,
				"customer_name": row.get("Customer_Name", "Unknown"),
				"dresses":       dresses_compat,
				"xp_reward":     xp_estimate,
				"coin_reward":   int(price),
				"timestamp":     row.get("Order_date", ""),
			}
		}

		pending_orders[order_id] = order_entry
		loaded += 1
		print("GameManager: Restored pending Order %d ('%s') from DB."
			  % [order_id, row.get("Customer_Name", "?")])

	if loaded > 0:
		print("GameManager: %d order(s) restored from previous session." % loaded)
		emit_signal("stats_changed")   # Refresh HUD to show pending count


# ── Stats sync ────────────────────────────────────────────────────────────────
func _sync_stats() -> void:
	# Database.get_player_data() → SELECT Level, Coins, Current_xp FROM Player
	var data: Dictionary = Database.get_player_data()
	player_level = data.get("Level",      1)
	player_xp    = data.get("Current_xp", 0)
	player_coins = data.get("Coins",      0)
	emit_signal("stats_changed")
