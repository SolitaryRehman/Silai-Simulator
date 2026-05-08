# database.gd
# AutoLoad as "Database" — must be ABOVE GameManager in the AutoLoad list.
extends Node

# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 1 — CONSTANTS & DATA POOLS
# ──────────────────────────────────────────────────────────────────────────────

const DB_PATH := "res://silai_simulator"

const VIP_NAMES: Array = [
	"Ahmed", "Sara", "Zara", "Hamza", "Fatima",
	"Ayesha", "Hassan", "Maryam", "Ali", "Noor"
]
const RUDE_NAMES: Array = [
	"Babar", "Javed", "Naseem", "Shafiq", "Gulzar",
	"Rafiq", "Munna", "Bhola", "Dada", "Chacha"
]
const NAME_POOL: Array = [
	"Ahmed", "Sara", "Zara", "Hamza", "Fatima",
	"Ayesha", "Hassan", "Maryam", "Ali", "Noor",
	"Babar", "Javed", "Naseem", "Shafiq", "Gulzar",
	"Rafiq", "Munna", "Bhola", "Dada", "Chacha",
	"Usman", "Bilal", "Kamran", "Raza", "Tariq",
	"Nadia", "Hira", "Sana", "Rabia", "Amna",
	"Imran", "Faisal", "Asad", "Omer", "Saad"
]

const HOUSE_POOL: Array = [
	"12-A", "45-B", "7-C", "88", "3/4", "22-D", "101", "56-F", "9-G", "77"
]
const STREET_POOL: Array = [
	"Gulshan Street", "Model Town Road", "Saddar Lane", "Cavalry Boulevard",
	"F-7 Street", "I-8 Road", "DHA Avenue", "Bahria Road", "PWD Road", "Peshawar Road"
]
const SECTOR_POOL: Array = [
	"G-9", "F-7", "I-8", "DHA Phase 2", "Bahria Phase 5",
	"Gulshan-e-Iqbal", "Model Town", "Cantt", "Satellite Town", "Askari-14"
]
const CITY_POOL: Array = [
	"Islamabad", "Rawalpindi", "Lahore", "Karachi", "Peshawar", "Quetta"
]

const COLLAR_RANGE:   Array = [13, 18]
const CHEST_RANGE:    Array = [32, 48]
const SHOULDER_RANGE: Array = [14, 20]
const SLEEVE_RANGE:   Array = [22, 28]
const TROUSER_RANGE:  Array = [36, 46]
const WAIST_RANGE:    Array = [28, 44]

const VIP_DISCOUNT_RANGE:  Array = [10, 25]
const RUDE_DELAY_RANGE:    Array = [1,   4]
const BASE_RECEIVING_DAYS: int   = 3

# ── Order generation pools — single source of truth for both customer scripts ──
const DRESS_POOL: Array = [
	"T-Shirt", "Frock", "Bishop Gown", "Pants", "Jacket", "Maxi", "Lehenga"
]
const FABRIC_POOL: Array = [
	"Cotton", "Silk", "Linen", "Polyester", "Lawn", "Chiffon", "Denim"
]
const COLOR_POOL: Array = [
	"Navy Blue", "Crimson Red", "Forest Green", "Pearl White",
	"Jet Black", "Purple", "Golden", "Sky Blue"
]
const FABRIC_USED_POOL: Array = [
	"2.5 meters", "3.0 meters", "3.5 meters", "4.0 meters",
	"4.5 meters", "5.0 meters", "5.5 meters"
]

# XP / coin ranges per number of dresses in one order
const XP_RANGES: Dictionary   = { 1: [50, 120],  2: [130, 250], 3: [260, 400] }
const COIN_RANGES: Dictionary = { 1: [100, 300], 2: [320, 550], 3: [570, 900] }

# Keys = dress_display.to_lower().replace(" ", "_")
# "T-Shirt" → "t-shirt"   |   "Bishop Gown" → "bishop_gown"
const DRESS_PARTS_TEMPLATE: Dictionary = {
	"t-shirt":     [["Front Panel", 1.5], ["Back Panel", 1.5], ["Sleeve", 0.5], ["Collar", 0.2]],
	"frock":       [["Bodice", 1.0], ["Skirt", 2.0], ["Sleeve", 0.5], ["Neckband", 0.3]],
	"bishop_gown": [["Bodice", 1.2], ["Skirt", 2.5], ["Bishop Sleeve", 0.8], ["Collar", 0.3]],
	"pants":       [["Front Panel", 1.5], ["Back Panel", 1.5], ["Waistband", 0.3], ["Pocket", 0.2]],
	"jacket":      [["Front Panel", 1.2], ["Back Panel", 1.2], ["Sleeve", 0.7], ["Lining", 0.8]],
	"maxi":        [["Bodice", 1.0], ["Skirt", 3.0], ["Sleeve", 0.5], ["Hem", 0.3]],
	"lehenga":     [["Skirt", 2.5], ["Blouse", 1.0], ["Dupatta", 2.0], ["Waistband", 0.3]],
}


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 2 — RUNTIME STATE
# ──────────────────────────────────────────────────────────────────────────────

var db: SQLite = null

var active_customer_id: int = -1
var active_order_id:    int = -1
var active_dress_id:    int = -1


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 3 — LIFECYCLE
# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_open_db()
	_create_tables()
	_create_triggers()
	_create_views()
	_prefill_data()
	print("═══ Database: Fully initialized. ═══")


func _notification(what: int) -> void:  #close db upon closing window
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_db()


func _open_db() -> void:
	db = SQLite.new()
	db.path            = DB_PATH
	db.verbosity_level = SQLite.QUIET #Do not print unnecessary logs/messages
	if not db.open_db():
		push_error("Database: FATAL — could not open '%s.db'!" % DB_PATH)
		return
	db.query("PRAGMA foreign_keys = ON;")
	print("Database: Connected to '%s.db'." % DB_PATH)


func _close_db() -> void:
	if db != null:
		db.close_db()
		print("Database: Connection closed.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 4 — DDL
# ──────────────────────────────────────────────────────────────────────────────

func _create_tables() -> void:
	db.query("""
		CREATE TABLE IF NOT EXISTS Customer (
			CustomerID      INTEGER PRIMARY KEY AUTOINCREMENT,
			Name            TEXT    NOT NULL UNIQUE,
			House           TEXT,
			Street          TEXT,
			Sector          TEXT,
			City            TEXT,
			Collar_size     REAL,
			Chest           REAL,
			Shoulder        REAL,
			Sleeve_length   REAL,
			Trouser_length  REAL,
			Waist           REAL
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Customer_Phone (
			CustomerID  INTEGER NOT NULL,
			PhoneNo     TEXT    NOT NULL,
			PRIMARY KEY (CustomerID, PhoneNo),
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
			ON DELETE CASCADE ON UPDATE CASCADE
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS VIP (
			CustomerID    INTEGER PRIMARY KEY,
			Discount_rate REAL    NOT NULL
			              CHECK(Discount_rate >= 0 AND Discount_rate <= 100),
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
			ON DELETE CASCADE ON UPDATE CASCADE
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Rude (
			CustomerID  INTEGER PRIMARY KEY,
			Time_delay  INTEGER NOT NULL CHECK(Time_delay >= 0),
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
			ON DELETE CASCADE ON UPDATE CASCADE
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Fabric (
			FabricID        INTEGER PRIMARY KEY AUTOINCREMENT,
			Fabric_type     TEXT    NOT NULL UNIQUE,
			Unit_cost       REAL    NOT NULL CHECK(Unit_cost > 0),
			Stock_quantity  INTEGER NOT NULL DEFAULT 100 CHECK(Stock_quantity >= 0)
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS ShopItems (
			ItemID        INTEGER PRIMARY KEY AUTOINCREMENT,
			Item_name     TEXT    NOT NULL UNIQUE,
			Price         REAL    NOT NULL CHECK(Price >= 0),
			Unlock_Status TEXT    NOT NULL DEFAULT 'Locked'
			              CHECK(Unlock_Status IN ('Locked', 'Unlocked')),
			Use_Status    TEXT    NOT NULL DEFAULT 'Not In Use'
			              CHECK(Use_Status IN ('In Use', 'Not In Use'))
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Machine (
			ItemID  INTEGER PRIMARY KEY,
			Type    TEXT    NOT NULL,
			Speed   REAL    NOT NULL DEFAULT 1.0 CHECK(Speed > 0),
			FOREIGN KEY (ItemID) REFERENCES ShopItems(ItemID)
			ON DELETE CASCADE ON UPDATE CASCADE
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Player (
			PlayerID    INTEGER PRIMARY KEY AUTOINCREMENT,
			Username    TEXT    NOT NULL UNIQUE,
			Level       INTEGER NOT NULL DEFAULT 1 CHECK(Level >= 1),
			Coins       INTEGER NOT NULL DEFAULT 500 CHECK(Coins >= 0),
			Current_xp  INTEGER NOT NULL DEFAULT 0 CHECK(Current_xp >= 0)
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS "Order" (
			OrderID         INTEGER PRIMARY KEY AUTOINCREMENT,
			CustomerID      INTEGER NOT NULL,
			Order_date      TEXT    NOT NULL,
			Receiving_date  TEXT    NOT NULL,
			Payment_status  TEXT    NOT NULL DEFAULT 'Unpaid'
			                CHECK(Payment_status IN ('Unpaid', 'Paid')),
			Order_status    TEXT    NOT NULL DEFAULT 'Pending'
			                CHECK(Order_status IN
			                      ('Pending','Cutting','Sewing','Completed','Cancelled')),
			Total_price     REAL    DEFAULT 0.0,
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Dress (
			DressID     INTEGER PRIMARY KEY AUTOINCREMENT,
			OrderID     INTEGER NOT NULL,
			Dress_type  TEXT    NOT NULL,
			FOREIGN KEY (OrderID) REFERENCES "Order"(OrderID)
			ON DELETE CASCADE ON UPDATE CASCADE
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Dress_Color (
			DressID  INTEGER NOT NULL,
			Color    TEXT    NOT NULL,
			PRIMARY KEY (DressID, Color),
			FOREIGN KEY (DressID) REFERENCES Dress(DressID)
			ON DELETE CASCADE ON UPDATE CASCADE
		);
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS Dress_Parts (
			DressID        INTEGER NOT NULL,
			Part_name      TEXT    NOT NULL,
			FabricID       INTEGER NOT NULL,
			Quantity_used  REAL    NOT NULL CHECK(Quantity_used > 0),
			PRIMARY KEY (DressID, Part_name, FabricID),
			FOREIGN KEY (DressID)  REFERENCES Dress(DressID)
			ON DELETE CASCADE ON UPDATE CASCADE,
			FOREIGN KEY (FabricID) REFERENCES Fabric(FabricID)
			ON DELETE RESTRICT ON UPDATE CASCADE
		);
	""")
	print("Database: All tables created / verified.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 5 — TRIGGERS
# ──────────────────────────────────────────────────────────────────────────────

func _create_triggers() -> void:
	# Level = floor(Current_xp / 500) + 1  (integer division, minimum 1)
	db.query("""
		CREATE TRIGGER IF NOT EXISTS trg_player_level_up
		AFTER UPDATE OF Current_xp ON Player
		FOR EACH ROW
		BEGIN
			UPDATE Player
			SET    Level = MAX(1, (NEW.Current_xp / 500) + 1)
			WHERE  PlayerID = NEW.PlayerID;
		END;
	""")
	# Deduct fabric stock automatically on each Dress_Parts INSERT
	db.query("""
		CREATE TRIGGER IF NOT EXISTS trg_deduct_fabric_stock
		AFTER INSERT ON Dress_Parts
		FOR EACH ROW
		BEGIN
			UPDATE Fabric
			SET    Stock_quantity = Stock_quantity - NEW.Quantity_used
			WHERE  FabricID = NEW.FabricID;
		END;
	""")
	# Payment trigger fires via deliver_order() (delivery button), not here.
	print("Database: Triggers created / verified.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 6 — VIEWS
# ──────────────────────────────────────────────────────────────────────────────

func _create_views() -> void:
	db.query("""
		CREATE VIEW IF NOT EXISTS v_order_summary AS
		SELECT
			o.OrderID,
			c.Name                         AS Customer_Name,
			c.City,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE                               'Normal'
			END                            AS Customer_Type,
			COALESCE(v.Discount_rate, 0)   AS Discount_pct,
			COALESCE(r.Time_delay,    0)   AS Delay_days,
			d.Dress_type,
			dc.Color,
			o.Order_date,
			o.Receiving_date,
			o.Order_status,
			o.Payment_status,
			ROUND(o.Total_price, 2)        AS Total_price
		FROM "Order"    o
		JOIN  Customer  c  ON c.CustomerID = o.CustomerID
		JOIN  Dress     d  ON d.OrderID    = o.OrderID
		LEFT JOIN Dress_Color dc ON dc.DressID   = d.DressID
		LEFT JOIN VIP   v  ON v.CustomerID = o.CustomerID
		LEFT JOIN Rude  r  ON r.CustomerID = o.CustomerID;
	""")
	db.query("""
		CREATE VIEW IF NOT EXISTS v_dress_cost_breakdown AS
		SELECT
			d.DressID,
			d.Dress_type,
			o.OrderID,
			c.Name                                   AS Customer_Name,
			dp.Part_name,
			f.Fabric_type,
			f.Unit_cost,
			dp.Quantity_used,
			ROUND(f.Unit_cost * dp.Quantity_used, 2) AS Part_cost
		FROM Dress         d
		JOIN "Order"       o  ON o.OrderID    = d.OrderID
		JOIN Customer      c  ON c.CustomerID = o.CustomerID
		JOIN Dress_Parts  dp  ON dp.DressID   = d.DressID
		JOIN Fabric        f  ON  f.FabricID  = dp.FabricID;
	""")
	db.query("""
		CREATE VIEW IF NOT EXISTS v_customer_spending AS
		SELECT
			c.CustomerID,
			c.Name,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE                               'Normal'
			END                            AS Customer_Type,
			COUNT(o.OrderID)               AS Total_orders,
			ROUND(SUM(o.Total_price), 2)   AS Total_spent,
			ROUND(AVG(o.Total_price), 2)   AS Avg_order_value
		FROM Customer  c
		JOIN "Order"   o ON o.CustomerID = c.CustomerID
		LEFT JOIN VIP  v ON v.CustomerID = c.CustomerID
		LEFT JOIN Rude r ON r.CustomerID = c.CustomerID
		WHERE o.Order_status = 'Completed'
		GROUP BY c.CustomerID, c.Name;
	""")
	print("Database: Views created / verified.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 7 — PREFILL
# ──────────────────────────────────────────────────────────────────────────────

func _prefill_data() -> void:
	_prefill_fabrics()
	_prefill_shop_items()
	_prefill_player()
	print("Database: Prefill complete.")


func _prefill_fabrics() -> void:
	var fabrics: Array = [
		{"type": "Cotton",    "cost": 50.0,  "stock": 100},
		{"type": "Silk",      "cost": 150.0, "stock": 50 },
		{"type": "Linen",     "cost": 80.0,  "stock": 75 },
		{"type": "Polyester", "cost": 40.0,  "stock": 120},
		{"type": "Lawn",      "cost": 60.0,  "stock": 90 },
		{"type": "Chiffon",   "cost": 120.0, "stock": 60 },
		{"type": "Denim",     "cost": 90.0,  "stock": 80 },
	]
	for f in fabrics:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Fabric (Fabric_type, Unit_cost, Stock_quantity) VALUES (?, ?, ?);",
			[f["type"], f["cost"], f["stock"]]
		)


func _prefill_shop_items() -> void:
	var items: Array = [
		{"name": "Embroidery Machine",  "price": 1000.0, "unlocked": false, "in_use": false},
		{"name": "Overlocking Machine", "price": 2500.0, "unlocked": false, "in_use": false},
		{"name": "Desi Machine",        "price":  500.0, "unlocked": true,  "in_use": true },
		{"name": "Cutting Table",       "price":  300.0, "unlocked": true,  "in_use": true },
		{"name": "Iron",                "price":  100.0, "unlocked": true,  "in_use": false},
		{"name": "Dress Form",          "price":  200.0, "unlocked": false, "in_use": false},
		{"name": "Display Rack",        "price":  150.0, "unlocked": false, "in_use": false},
	]
	for item in items:
		var unlock_s: String = "Unlocked" if item["unlocked"] else "Locked"
		var use_s:    String = "In Use"   if item["in_use"]   else "Not In Use"
		db.query_with_bindings(
			"INSERT OR IGNORE INTO ShopItems (Item_name, Price, Unlock_Status, Use_Status) VALUES (?, ?, ?, ?);",
			[item["name"], item["price"], unlock_s, use_s]
		)
	var machines: Array = [
		{"name": "Embroidery Machine",  "type": "Electrical", "speed": 10.0},
		{"name": "Overlocking Machine", "type": "Electrical", "speed": 15.0},
		{"name": "Desi Machine",        "type": "Mechanical", "speed":  2.0},
	]
	for machine in machines:
		db.query_with_bindings(
			"SELECT ItemID FROM ShopItems WHERE Item_name = ?;",
			[machine["name"]]
		)
		if not db.query_result.is_empty():
			var mid: int = db.query_result[0]["ItemID"]
			db.query_with_bindings(
				"INSERT OR IGNORE INTO Machine (ItemID, Type, Speed) VALUES (?, ?, ?);",
				[mid, machine["type"], machine["speed"]]
			)


func _prefill_player() -> void:
	db.query("SELECT COUNT(*) AS cnt FROM Player;")
	if db.query_result[0]["cnt"] == 0:
		db.query("INSERT INTO Player (Username, Level, Coins, Current_xp) VALUES ('Tailor', 1, 500, 0);")
		print("Database: Default player 'Tailor' created.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 8 — CUSTOMER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

func get_random_name() -> String:
	return NAME_POOL[randi() % NAME_POOL.size()]


## Step 1: check DB by Name.
## Found  → return stored record (returning customer).
## Not found → generate from pools, INSERT, classify VIP/Rude.
func get_or_create_customer(name: String) -> Dictionary:
	db.query_with_bindings("SELECT * FROM Customer WHERE Name = ?;", [name])
	if not db.query_result.is_empty():
		var customer: Dictionary  = db.query_result[0].duplicate()
		active_customer_id        = customer["CustomerID"]
		customer["customer_type"] = _resolve_customer_type(active_customer_id)
		print("Database: Returning customer '%s' (ID=%d, Type=%s)."
			  % [name, active_customer_id, customer["customer_type"]])
		return customer
	else:
		var generated: Dictionary = _generate_customer_record(name)
		_insert_full_customer(generated)
		generated["customer_type"] = _resolve_customer_type(active_customer_id)
		generated["CustomerID"]    = active_customer_id
		print("Database: New customer '%s' created (ID=%d, Type=%s)."
			  % [name, active_customer_id, generated["customer_type"]])
		return generated


func _resolve_customer_type(customer_id: int) -> String:
	db.query_with_bindings("SELECT CustomerID FROM VIP  WHERE CustomerID = ?;", [customer_id])
	if not db.query_result.is_empty(): return "VIP"
	db.query_with_bindings("SELECT CustomerID FROM Rude WHERE CustomerID = ?;", [customer_id])
	if not db.query_result.is_empty(): return "Rude"
	return "Normal"


func _generate_customer_record(name: String) -> Dictionary:
	return {
		"Name":           name,
		"House":          HOUSE_POOL[randi()  % HOUSE_POOL.size()],
		"Street":         STREET_POOL[randi() % STREET_POOL.size()],
		"Sector":         SECTOR_POOL[randi() % SECTOR_POOL.size()],
		"City":           CITY_POOL[randi()   % CITY_POOL.size()],
		"Collar_size":    float(randi_range(COLLAR_RANGE[0],   COLLAR_RANGE[1])),
		"Chest":          float(randi_range(CHEST_RANGE[0],    CHEST_RANGE[1])),
		"Shoulder":       float(randi_range(SHOULDER_RANGE[0], SHOULDER_RANGE[1])),
		"Sleeve_length":  float(randi_range(SLEEVE_RANGE[0],   SLEEVE_RANGE[1])),
		"Trouser_length": float(randi_range(TROUSER_RANGE[0],  TROUSER_RANGE[1])),
		"Waist":          float(randi_range(WAIST_RANGE[0],    WAIST_RANGE[1])),
	}


func _insert_full_customer(data: Dictionary) -> void:
	db.query_with_bindings("""
		INSERT INTO Customer
			(Name, House, Street, Sector, City,
			 Collar_size, Chest, Shoulder, Sleeve_length, Trouser_length, Waist)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
	""", [
		data["Name"], data["House"], data["Street"], data["Sector"], data["City"],
		data["Collar_size"], data["Chest"], data["Shoulder"],
		data["Sleeve_length"], data["Trouser_length"], data["Waist"]
	])
	db.query("SELECT last_insert_rowid() AS id;")
	active_customer_id = int(db.query_result[0]["id"])

	# 1–3 phone numbers per customer (multivalued attribute)
	var num_phones: int = randi() % 3 + 1
	for _i in range(num_phones):
		var phone: String = "03%01d%01d-%07d" % [
			randi() % 4, randi() % 10, randi() % 10000000
		]
		db.query_with_bindings(
			"INSERT INTO Customer_Phone (CustomerID, PhoneNo) VALUES (?, ?);",
			[active_customer_id, phone]
		)

	var name: String = data["Name"]
	if name in VIP_NAMES:
		var discount: float = float(randi_range(VIP_DISCOUNT_RANGE[0], VIP_DISCOUNT_RANGE[1]))
		db.query_with_bindings(
			"INSERT OR IGNORE INTO VIP (CustomerID, Discount_rate) VALUES (?, ?);",
			[active_customer_id, discount]
		)
		print("Database: '%s' → VIP (%.0f%% discount)." % [name, discount])
	elif name in RUDE_NAMES:
		var delay: int = randi_range(RUDE_DELAY_RANGE[0], RUDE_DELAY_RANGE[1])
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Rude (CustomerID, Time_delay) VALUES (?, ?);",
			[active_customer_id, delay]
		)
		print("Database: '%s' → Rude (+%d day delay)." % [name, delay])
	else:
		print("Database: '%s' → Normal customer." % name)


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 9 — ORDER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

## Called at Accept press. Returns the new OrderID.
func create_order_record(customer_id: int) -> int:
	var order_date:     String = Time.get_datetime_string_from_system()
	var receiving_date: String = _compute_receiving_date(customer_id)
	db.query_with_bindings("""
		INSERT INTO "Order"
			(CustomerID, Order_date, Receiving_date, Payment_status, Order_status, Total_price)
		VALUES (?, ?, ?, 'Unpaid', 'Pending', 0.0);
	""", [customer_id, order_date, receiving_date])
	db.query("SELECT last_insert_rowid() AS id;")
	active_order_id = int(db.query_result[0]["id"])
	print("Database: Order %d created (Customer %d, due %s)."
		  % [active_order_id, customer_id, receiving_date])
	return active_order_id


## Uses get_rude_delay() utility — single source of truth for delay logic.
func _compute_receiving_date(customer_id: int) -> String:
	var total_days: int   = BASE_RECEIVING_DAYS + get_rude_delay(customer_id)
	var future_unix: int  = int(Time.get_unix_time_from_system()) + (total_days * 86400)
	var dt: Dictionary    = Time.get_datetime_dict_from_unix_time(future_unix)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Called right after create_order_record() at Accept press.
## Loops ALL dresses in the order (1–3) and inserts each one with its random
## dress / color / fabric that was already decided by generate_random_dress_order().
func attach_all_dresses_to_order(order_id: int, order_data: Dictionary) -> void:
	var dresses: Array = order_data.get("dresses", [])
	if dresses.is_empty():
		push_warning("Database: attach_all_dresses_to_order — no dresses in order dict!")
		return
	for dress_dict in dresses:
		_attach_single_dress(
			order_id,
			dress_dict.get("dress",  "T-Shirt"),
			dress_dict.get("color",  "Navy Blue"),
			dress_dict.get("fabric", "Cotton")
		)
	print("Database: %d dress(es) attached to Order %d." % [dresses.size(), order_id])


## Internal — inserts one Dress + Dress_Color + Dress_Parts.
## Does NOT modify Order_status (handled by update_order_status).
func _attach_single_dress(
		order_id:      int,
		dress_display: String,
		color:         String,
		fabric_type:   String
) -> void:
	db.query_with_bindings(
		"INSERT INTO Dress (OrderID, Dress_type) VALUES (?, ?);",
		[order_id, dress_display]
	)
	db.query("SELECT last_insert_rowid() AS id;")
	active_dress_id = int(db.query_result[0]["id"])

	db.query_with_bindings(
		"INSERT OR IGNORE INTO Dress_Color (DressID, Color) VALUES (?, ?);",
		[active_dress_id, color]
	)

	db.query_with_bindings(
		"SELECT FabricID FROM Fabric WHERE Fabric_type = ?;",
		[fabric_type]
	)
	if db.query_result.is_empty():
		push_error("Database: Fabric '%s' not found — using Cotton fallback." % fabric_type)
		db.query("SELECT FabricID FROM Fabric WHERE Fabric_type = 'Cotton';")
		if db.query_result.is_empty():
			return
	var fabric_id: int = int(db.query_result[0]["FabricID"])

	var key: String = dress_display.to_lower().replace(" ", "_")
	if not DRESS_PARTS_TEMPLATE.has(key):
		push_warning("Database: No parts template for key '%s'." % key)
		return
	for part in DRESS_PARTS_TEMPLATE[key]:
		db.query_with_bindings("""
			INSERT OR IGNORE INTO Dress_Parts (DressID, Part_name, FabricID, Quantity_used)
			VALUES (?, ?, ?, ?);
		""", [active_dress_id, part[0], fabric_id, float(part[1])])
		# trg_deduct_fabric_stock fires automatically per INSERT


## Updates Order_status. Called by GameManager at each workflow stage.
func update_order_status(order_id: int, new_status: String) -> void:
	db.query_with_bindings(
		"UPDATE \"Order\" SET Order_status = ? WHERE OrderID = ?;",
		[new_status, order_id]
	)


## Finalizes a sewn order — computes Total_price, sets Order_status = 'Completed'.
## Payment_status = 'Paid' is set separately by deliver_order() (delivery button).
##
## TOTAL_PRICE DERIVATION (derived attribute):
##   Σ(Fabric.Unit_cost × Dress_Parts.Quantity_used) for all parts in this order
##   × (1.0 - VIP discount / 100.0)  via correlated sub-subquery on VIP table.
##   Covers: 2 INNER JOINs, correlated subquery, sub-subquery, COALESCE, ROUND, SUM.
func finalize_order(order_id: int) -> void:
	if order_id <= 0:
		push_error("Database: finalize_order() — invalid order_id: %d" % order_id)
		return
	db.query_with_bindings("""
		UPDATE "Order"
		SET
			Order_status = 'Completed',
			Total_price  = (
				SELECT ROUND(
					COALESCE(SUM(f.Unit_cost * dp.Quantity_used), 0.0)
					*
					(1.0 - COALESCE(
						(
							SELECT v.Discount_rate / 100.0
							FROM   VIP       v
							JOIN   "Order"   o_v ON o_v.CustomerID = v.CustomerID
							WHERE  o_v.OrderID = ?
						),
						0.0
					)),
					2
				)
				FROM  Dress       d
				JOIN  Dress_Parts dp ON dp.DressID  = d.DressID
				JOIN  Fabric       f ON  f.FabricID = dp.FabricID
				WHERE d.OrderID = ?
			)
		WHERE OrderID = ?;
	""", [order_id, order_id, order_id])

	db.query_with_bindings(
		"SELECT Total_price FROM \"Order\" WHERE OrderID = ?;",
		[order_id]
	)
	var price: float = 0.0
	if not db.query_result.is_empty():
		var raw = db.query_result[0]["Total_price"]
		price = 0.0 if raw == null else float(raw)
	print("Database: Order %d finalized. Total_price = %.2f coins." % [order_id, price])


## Called when player presses Deliver button.
## Sets Payment_status = 'Paid' only for Completed orders.
func deliver_order(order_id: int) -> void:
	db.query_with_bindings("""
		UPDATE "Order"
		SET    Payment_status = 'Paid'
		WHERE  OrderID        = ?
		  AND  Order_status   = 'Completed';
	""", [order_id])
	print("Database: Order %d delivered — Payment marked Paid." % order_id)


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 10 — PLAYER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

## Adds XP + Coins. trg_player_level_up recalculates Level automatically.
func add_player_rewards(xp: int, coins: int) -> void:
	db.query_with_bindings("""
		UPDATE Player
		SET Current_xp = Current_xp + ?,
		    Coins      = Coins      + ?
		WHERE PlayerID = 1;
	""", [xp, coins])
	print("Database: Player rewarded +%d XP, +%d coins." % [xp, coins])


## Full player stats including computed xp_to_next_level.
## Called by GameManager._ready() and _sync_stats() to load/refresh HUD.
func get_player_data() -> Dictionary:
	db.query("""
		SELECT
			PlayerID,
			Username,
			Level,
			Coins,
			Current_xp,
			(Level * 500) - Current_xp AS xp_to_next_level
		FROM Player
		WHERE PlayerID = 1;
	""")
	if db.query_result.is_empty():
		return {}
	return db.query_result[0].duplicate()


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 11 — UTILITY / QUERY HELPERS
# ──────────────────────────────────────────────────────────────────────────────

## Generates a random order dict for a customer.
## Called by berserk_armor.gd and girl_1.gd — single source of truth for all pools.
func generate_random_dress_order(customer_name: String) -> Dictionary:
	var num_dresses: int = randi_range(1, 3)
	var dresses: Array   = []
	for _i in range(num_dresses):
		dresses.append({
			"dress":  DRESS_POOL[randi()  % DRESS_POOL.size()],
			"fabric": FABRIC_POOL[randi() % FABRIC_POOL.size()],
			"color":  COLOR_POOL[randi()  % COLOR_POOL.size()],
		})
	var xp_range:   Array = XP_RANGES[num_dresses]
	var coin_range: Array = COIN_RANGES[num_dresses]
	return {
		"customer_name": customer_name,
		"dresses":       dresses,
		"fabric_used":   FABRIC_USED_POOL[randi() % FABRIC_USED_POOL.size()],
		"xp_reward":     randi_range(xp_range[0],   xp_range[1]),
		"coin_reward":   randi_range(coin_range[0],  coin_range[1]),
		"timestamp":     Time.get_datetime_string_from_system(),
		"status":        "pending"
	}


func get_vip_discount(customer_id: int) -> float:
	db.query_with_bindings(
		"SELECT Discount_rate FROM VIP WHERE CustomerID = ?;",
		[customer_id]
	)
	if db.query_result.is_empty(): return 0.0
	return float(db.query_result[0]["Discount_rate"])


## Rude delay days — used by _compute_receiving_date and UI display labels.
func get_rude_delay(customer_id: int) -> int:
	db.query_with_bindings(
		"SELECT Time_delay FROM Rude WHERE CustomerID = ?;",
		[customer_id]
	)
	if db.query_result.is_empty(): return 0
	return int(db.query_result[0]["Time_delay"])


## All orders currently in progress: Pending.
## Called from cutting table when player selects which order to work on.
func get_pending_orders() -> Array:
	db.query("""
		SELECT
			o.OrderID,
			c.Name                             AS Customer_Name,
			c.City,
			GROUP_CONCAT(d.Dress_type, ', ')   AS Dresses,
			o.Order_date,
			o.Receiving_date,
			o.Order_status,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE                               'Normal'
			END                                AS Customer_Type
		FROM "Order"   o
		JOIN  Customer  c  ON c.CustomerID = o.CustomerID
		LEFT JOIN Dress d  ON d.OrderID    = o.OrderID
		LEFT JOIN VIP   v  ON v.CustomerID = o.CustomerID
		LEFT JOIN Rude  r  ON r.CustomerID = o.CustomerID
		WHERE o.Order_status IN ('Pending')
		GROUP BY o.OrderID
		ORDER BY o.OrderID ASC;
	""")
	return db.query_result.duplicate()


## Sectors / cities with most completed-but-unpaid orders — for batch delivery.
func get_top_delivery_areas(limit: int = 5) -> Array:
	db.query_with_bindings("""
		SELECT
			c.Sector,
			c.City,
			COUNT(o.OrderID)             AS Pending_deliveries,
			ROUND(SUM(o.Total_price), 2) AS Area_revenue
		FROM "Order"   o
		JOIN  Customer c ON c.CustomerID = o.CustomerID
		WHERE o.Order_status   = 'Completed'
		  AND o.Payment_status = 'Unpaid'
		GROUP BY c.Sector, c.City
		ORDER BY Pending_deliveries DESC
		LIMIT ?;
	""", [limit])
	return db.query_result.duplicate()


func get_order_details(order_id: int) -> Dictionary:
	db.query_with_bindings("SELECT * FROM v_order_summary WHERE OrderID = ?;", [order_id])
	if db.query_result.is_empty(): return {}
	return db.query_result[0].duplicate()


func get_dress_cost_breakdown(dress_id: int) -> Array:
	db.query_with_bindings("SELECT * FROM v_dress_cost_breakdown WHERE DressID = ?;", [dress_id])
	return db.query_result.duplicate()


func get_order_history() -> Array:
	db.query("""
		SELECT * FROM v_order_summary
		WHERE Order_status = 'Completed'
		ORDER BY OrderID DESC;
	""")
	return db.query_result.duplicate()


func get_total_earnings() -> float:
	db.query("""
		SELECT ROUND(COALESCE(SUM(COALESCE(Total_price, 0.0)), 0.0), 2) AS earnings
		FROM "Order"
		WHERE Order_status = 'Completed';
	""")
	return float(db.query_result[0]["earnings"])


func get_top_customers(limit: int = 5) -> Array:
	db.query_with_bindings(
		"SELECT * FROM v_customer_spending ORDER BY Total_spent DESC LIMIT ?;",
		[limit]
	)
	return db.query_result.duplicate()
