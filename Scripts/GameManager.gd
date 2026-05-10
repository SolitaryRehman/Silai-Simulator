# gamemanager.gd
extends Node

signal order_received(order_data)
signal garment_sewn(garment_type)
signal stats_changed

# what the player is doing right now
enum GameState {
	FREE_ROAM,
	CUTTING,    # in the cutting minigame — not written to DB anymore
	SEWING,     # in the sewing minigame — not written to DB anymore
	DELIVERING
}

var current_state: GameState = GameState.FREE_ROAM

# all accepted orders waiting to be worked on — keyed by db_order_id
var pending_orders: Dictionary = {}

# the one order actively being cut/sewn right now
var current_order: Dictionary = {}

# dress-by-dress tracking within the active order
var order_dresses:       Array = []
var current_dress_index: int   = 0

var cut_pieces:   Array = []
var is_piece_cut: bool  = false

# mirrors of the player's DB stats — used by the HUD
var player_level: int = 1
var player_xp:    int = 0
var player_coins: int = 0


func _ready() -> void:
	# pull the player's level/xp/coins from the DB straight away
	_sync_stats()

	# restore any orders that were pending when the game was last closed
	_load_pending_orders_from_db()

	print("GameManager: Ready — Level %d | XP %d | Coins %d | Pending orders: %d"
		  % [player_level, player_xp, player_coins, pending_orders.size()])


# ── Called by customer scripts on Accept ──────────────────────────────────────

func receive_order(order: Dictionary) -> void:
	var db_order_id: int = order.get("db_order_id", -1)

	# store just enough info for the queue; the full order dict stays in "full"
	var order_entry: Dictionary = {
		"type":   order["dresses"][0]["dress"].to_lower().replace(" ", "_"),
		"status": "pending_cut",
		"full":   order
	}

	if db_order_id > 0:
		pending_orders[db_order_id] = order_entry

	emit_signal("order_received", order_entry)
	print("GameManager: Order queued (ID=%d). Queue size: %d"
		  % [db_order_id, pending_orders.size()])


# ── Activate a specific pending order for cutting ─────────────────────────────

# loads the dress list from DB so the cutting table can loop through them one by one
func set_active_order(db_order_id: int) -> bool:
	if not pending_orders.has(db_order_id):
		push_warning("GameManager: set_active_order — ID %d not in queue." % db_order_id)
		return false

	current_order = pending_orders[db_order_id]
	cut_pieces.clear()
	is_piece_cut = false

	# fetch the full dress breakdown from DB — works for both new and restored orders
	order_dresses       = Database.get_dresses_for_order(db_order_id)
	current_dress_index = 0

	print("GameManager: Order %d is now active — %d dress(es) to process."
		  % [db_order_id, order_dresses.size()])
	return true


# convenience helper — just grabs the lowest-ID order when only one at a time is needed
func set_first_pending_order() -> bool:
	if pending_orders.is_empty():
		return false
	var keys: Array = pending_orders.keys()
	keys.sort()
	return set_active_order(keys[0])


# ── Cutting complete ──────────────────────────────────────────────────────────

# just flips local state — we no longer write 'Cutting' to the DB
func complete_cutting() -> void:
	is_piece_cut            = true
	current_order["status"] = "pending_sew"
	emit_signal("garment_sewn", current_order.get("type", "t-shirt"))   # kept for compatibility


# ── Sewing complete ───────────────────────────────────────────────────────────

# called only once ALL dresses in the order are done — then we finalize in DB
func complete_sewing() -> void:
	current_order["status"] = "complete"

	var full:     Dictionary = current_order.get("full", {})
	var order_id: int        = full.get("db_order_id", -1)

	# remove from the local queue
	if order_id > 0 and pending_orders.has(order_id):
		pending_orders.erase(order_id)

	# mark as Completed in the DB — payment happens later at dispatch
	if order_id > 0:
		Database.finalize_order(order_id)

	_sync_stats()

	print("═══ Order Complete (awaiting dispatch for rewards) ═══")
	print("  Order ID: %d  |  Orders still pending: %d" % [order_id, pending_orders.size()])
	print("═══════════════════════════════════════════════════════")

	# wipe active order state so the table is ready for the next one
	current_order       = {}
	order_dresses       = []
	current_dress_index = 0
	current_state       = GameState.FREE_ROAM

	emit_signal("garment_sewn", "complete")


# ── Session persistence ───────────────────────────────────────────────────────

# runs at startup — reads all 'Pending' orders from DB and rebuilds the queue
# so the player can continue from where they left off after closing the game
func _load_pending_orders_from_db() -> void:
	var db_rows: Array = Database.get_pending_orders()
	var loaded: int    = 0

	for row in db_rows:
		var order_id: int = int(row["OrderID"])
		# skip anything already in the queue from this session
		if pending_orders.has(order_id):
			continue

		# grab the dress breakdown and estimate rewards since they're not stored in DB
		var dresses_raw: Array = Database.get_dresses_for_order(order_id)
		var xp_estimate: int   = 50 * max(dresses_raw.size(), 1)
		var price: float       = Database.calculate_order_price(order_id)

		# build a dresses array in the same format the rest of the code expects
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
		# tell the HUD there's new stuff to show
		emit_signal("stats_changed")


# ── Stats sync ────────────────────────────────────────────────────────────────

# pull the latest level/xp/coins from DB and update the HUD
func _sync_stats() -> void:
	var data: Dictionary = Database.get_player_data()
	player_level = data.get("Level",      1)
	player_xp    = data.get("Current_xp", 0)
	player_coins = data.get("Coins",      0)
	emit_signal("stats_changed")
