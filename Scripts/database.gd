# database.gd
# ══════════════════════════════════════════════════════════════════════════════
#  SILAI SIMULATOR — Central Database Manager
#  AutoLoad this as "Database" in:
#    Project Settings → AutoLoad → Add → res://database.gd → Name: Database
#
#  Requires: godot-sqlite plugin by 2shady4u
#    (Project → Project Settings → Plugins → Enable "godot-sqlite")
# ══════════════════════════════════════════════════════════════════════════════
extends Node


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 1 — CONSTANTS & DATA POOLS
# ──────────────────────────────────────────────────────────────────────────────

const DB_PATH := "res://silai_simulator"   # godot-sqlite appends .db automatically

# ── Customer Type Classification ──────────────────────────────────────────────
# Names in VIP_NAMES  → get a random discount (10–25 %)
# Names in RUDE_NAMES → get a random extra delay (1–4 days)
# Everything else     → Normal (no discount, base 3-day receiving)
const VIP_NAMES: Array = [
	"Ahmed", "Sara", "Zara", "Hamza", "Fatima",
	"Ayesha", "Hassan", "Maryam", "Ali", "Noor"
]
const RUDE_NAMES: Array = [
	"Babar", "Javed", "Naseem", "Shafiq", "Gulzar",
	"Rafiq", "Munna", "Bhola", "Dada", "Chacha"
]

# Full name pool used by berserkarmor.gd to pick a random customer name
const NAME_POOL: Array = [
	# VIP
	"Ahmed", "Sara", "Zara", "Hamza", "Fatima",
	"Ayesha", "Hassan", "Maryam", "Ali", "Noor",
	# Rude
	"Babar", "Javed", "Naseem", "Shafiq", "Gulzar",
	"Rafiq", "Munna", "Bhola", "Dada", "Chacha",
	# Normal
	"Usman", "Bilal", "Kamran", "Raza", "Tariq",
	"Nadia", "Hira", "Sana", "Rabia", "Amna",
	"Imran", "Faisal", "Asad", "Omer", "Saad"
]

# ── Address pools ─────────────────────────────────────────────────────────────
const HOUSE_POOL:  Array = [
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

# ── Measurement ranges [min, max] in inches ───────────────────────────────────
const COLLAR_RANGE:   Array = [13, 18]
const CHEST_RANGE:    Array = [32, 48]
const SHOULDER_RANGE: Array = [14, 20]
const SLEEVE_RANGE:   Array = [22, 28]
const TROUSER_RANGE:  Array = [36, 46]
const WAIST_RANGE:    Array = [28, 44]

# ── VIP / Rude ranges ─────────────────────────────────────────────────────────
const VIP_DISCOUNT_RANGE:    Array = [10, 25]   # percent off total price
const RUDE_DELAY_RANGE:      Array = [1,   4]   # extra days added to receiving date
const BASE_RECEIVING_DAYS:   int   = 3          # normal receiving window (days)

# ── Dress parts template ──────────────────────────────────────────────────────
# Keys MUST match what GameManager produces:
#   dress_name.to_lower().replace(" ", "_")
# e.g. "T-Shirt" → "t-shirt"  |  "Bishop Gown" → "bishop_gown"
# Each entry: [Part_name, Quantity_used (metres)]
# Max 4 parts per dress (schema limit for this project)
const DRESS_PARTS_TEMPLATE: Dictionary = {
	"t-shirt":     [
		["Front Panel",  1.5],
		["Back Panel",   1.5],
		["Sleeve",       0.5],
		["Collar",       0.2]
	],
	"frock":       [
		["Bodice",       1.0],
		["Skirt",        2.0],
		["Sleeve",       0.5],
		["Neckband",     0.3]
	],
	"bishop_gown": [
		["Bodice",       1.2],
		["Skirt",        2.5],
		["Bishop Sleeve",0.8],
		["Collar",       0.3]
	],
	"pants":       [
		["Front Panel",  1.5],
		["Back Panel",   1.5],
		["Waistband",    0.3],
		["Pocket",       0.2]
	],
	"jacket":      [
		["Front Panel",  1.2],
		["Back Panel",   1.2],
		["Sleeve",       0.7],
		["Lining",       0.8]
	],
	"maxi":        [
		["Bodice",       1.0],
		["Skirt",        3.0],
		["Sleeve",       0.5],
		["Hem",          0.3]
	],
	"lehenga":     [
		["Skirt",        2.5],
		["Blouse",       1.0],
		["Dupatta",      2.0],
		["Waistband",    0.3]
	],
}


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 2 — RUNTIME STATE
# ──────────────────────────────────────────────────────────────────────────────

var db: SQLite = null

# Track the IDs of the currently active workflow so other scripts
# can call Database.active_order_id without passing parameters around.
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_db()


func _open_db() -> void:
	db = SQLite.new()
	db.path             = DB_PATH
	db.verbosity_level  = SQLite.QUIET   # change to SQLite.NORMAL for debug output
	if not db.open_db():
		push_error("Database: FATAL — could not open database at '%s.db'!" % DB_PATH)
		return
	# Enable foreign key enforcement (off by default in SQLite)
	db.query("PRAGMA foreign_keys = ON;")
	print("Database: Connected to '%s.db'." % DB_PATH)


func _close_db() -> void:
	if db != null:
		db.close_db()
		print("Database: Connection closed.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 4 — DDL (Data Definition Language)
#  Creates every table in the final relational schema.
# ──────────────────────────────────────────────────────────────────────────────

func _create_tables() -> void:

	# ── Customer ──────────────────────────────────────────────────────────────
	# Name is UNIQUE so a returning customer is found by name, not random ID.
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

	# ── Customer_Phone — multivalued attribute, separate relation ─────────────
	db.query("""
		CREATE TABLE IF NOT EXISTS Customer_Phone (
			CustomerID  INTEGER NOT NULL,
			PhoneNo     TEXT    NOT NULL,
			PRIMARY KEY (CustomerID, PhoneNo),
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) 
			ON DELETE CASCADE
			ON UPDATE CASCADE
		);
	""")

	# ── VIP — specialization subclass ────────────────────────────────────────
	db.query("""
		CREATE TABLE IF NOT EXISTS VIP (
			CustomerID    INTEGER PRIMARY KEY,
			Discount_rate REAL    NOT NULL
			              CHECK(Discount_rate >= 0 AND Discount_rate <= 100),
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) 
			ON DELETE CASCADE
			ON UPDATE CASCADE
		);
	""")

	# ── Rude — specialization subclass ───────────────────────────────────────
	db.query("""
		CREATE TABLE IF NOT EXISTS Rude (
			CustomerID  INTEGER PRIMARY KEY,
			Time_delay  INTEGER NOT NULL CHECK(Time_delay >= 0),
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) 
			ON DELETE CASCADE 
			ON UPDATE CASCADE
		);
	""")

	# ── Fabric ────────────────────────────────────────────────────────────────
	db.query("""
		CREATE TABLE IF NOT EXISTS Fabric (
			FabricID        INTEGER PRIMARY KEY AUTOINCREMENT,
			Fabric_type     TEXT    NOT NULL UNIQUE,
			Unit_cost       REAL    NOT NULL CHECK(Unit_cost > 0),
			Stock_quantity  INTEGER NOT NULL DEFAULT 100 CHECK(Stock_quantity >= 0)
		);
	""")

	# ── ShopItems (superclass) ────────────────────────────────────────────────
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

	# ── Machine — specialization subclass of ShopItems ───────────────────────
	db.query("""
		CREATE TABLE IF NOT EXISTS Machine (
			ItemID  INTEGER PRIMARY KEY,
			Type    TEXT    NOT NULL,
			Speed   REAL    NOT NULL DEFAULT 1.0 CHECK(Speed > 0),
			FOREIGN KEY (ItemID) REFERENCES ShopItems(ItemID) 
			ON DELETE CASCADE
			ON UPDATE CASCADE
		);
	""")

	# ── Player ────────────────────────────────────────────────────────────────
	# Level is a calculated attribute (computed by trigger from Current_xp).
	# Formula: Level = floor(Current_xp / 500) + 1
	db.query("""
		CREATE TABLE IF NOT EXISTS Player (
			PlayerID    INTEGER PRIMARY KEY AUTOINCREMENT,
			Username    TEXT    NOT NULL UNIQUE,
			Level       INTEGER NOT NULL DEFAULT 1 CHECK(Level >= 1),
			Coins       INTEGER NOT NULL DEFAULT 500 CHECK(Coins >= 0),
			Current_xp  INTEGER NOT NULL DEFAULT 0 CHECK(Current_xp >= 0)
		);
	""")

	# ── Order ─────────────────────────────────────────────────────────────────
	# Total_price is a DERIVED attribute computed via SQL on finalize_order(). improves query performance (real world decision of keeping total price in table)
	# Using quoted "Order" because ORDER is a reserved SQL keyword.
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
			Total_price     REAL             DEFAULT 0.0, 
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
		);
	""")

	# ── Dress ─────────────────────────────────────────────────────────────────
	db.query("""
		CREATE TABLE IF NOT EXISTS Dress (
			DressID     INTEGER PRIMARY KEY AUTOINCREMENT,
			OrderID     INTEGER NOT NULL,
			Dress_type  TEXT    NOT NULL,
			FOREIGN KEY (OrderID) REFERENCES "Order"(OrderID) 
			ON DELETE CASCADE
			ON UPDATE CASCADE
		);
	""")

	# ── Dress_Color — multivalued attribute (Phase 3, Step 6) ─────────────────
	db.query("""
		CREATE TABLE IF NOT EXISTS Dress_Color (
			DressID  INTEGER NOT NULL,
			Color    TEXT    NOT NULL,
			PRIMARY KEY (DressID, Color),
			FOREIGN KEY (DressID) REFERENCES Dress(DressID) 
			ON DELETE CASCADE
			ON UPDATE CASCADE
		);
	""")

	# ── Dress_Parts — merged M:N (Dress ↔ Fabric) + weak entity ─────────────
	# Composite PK: (DressID, Part_name)
	# Represents which fabric and how much is used per part of a dress. CHANGED PK ADDED FABRICID
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
#  SECTION 5 — TRIGGERS (Course topic: Week 14)
# ──────────────────────────────────────────────────────────────────────────────

func _create_triggers() -> void:

	# ── Trigger 1: Auto-level Player when XP changes ──────────────────────────
	# Level = floor(Current_xp / 500) + 1, minimum 1. single slash performs integer division!
	# Fires AFTER every XP update so the level is always in sync.
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

	# ── Trigger 2: Deduct fabric stock when a dress part is inserted ──────────
	# Each INSERT into Dress_Parts automatically reduces the Fabric stock.
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

	# ── Trigger 3: Auto-mark Payment as Paid when Order is Completed ──────────
	# Fires whenever Order_status is updated to 'Completed'.
	#db.query("""
		#CREATE TRIGGER IF NOT EXISTS trg_order_auto_pay
		#AFTER UPDATE OF Order_status ON "Order"
		#FOR EACH ROW
		#WHEN NEW.Order_status = 'Completed'
		#BEGIN
			#UPDATE "Order"
			#SET    Payment_status = 'Paid'
			#WHERE  OrderID = NEW.OrderID;
		#END;
	#""")  DO THIS AFTER DELIVERY FUNCTIONALITY ADDED!!!!!!

	print("Database: Triggers created / verified.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 6 — VIEWS (heavily use JOINs and subqueries — Week 5 & 6)
# ──────────────────────────────────────────────────────────────────────────────

func _create_views() -> void:

	# ── View 1: Full order summary (JOIN across 6 tables + LEFT JOINs) ────────
	db.query("""
		CREATE VIEW IF NOT EXISTS v_order_summary AS
		SELECT
			o.OrderID,
			c.Name AS Customer_Name,
			c.City,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE 'Normal'
			END AS Customer_Type,
			COALESCE(v.Discount_rate, 0) AS Discount_pct,
			COALESCE(r.Time_delay, 0) AS Delay_days,
			d.Dress_type,
			dc.Color,
			o.Order_date,
			o.Receiving_date,
			o.Order_status,
			o.Payment_status,
			ROUND(o.Total_price, 2) AS Total_price
		FROM "Order"    o
		JOIN  Customer  c  ON c.CustomerID = o.CustomerID
		JOIN  Dress     d  ON d.OrderID    = o.OrderID
		LEFT JOIN Dress_Color dc ON dc.DressID   = d.DressID
		LEFT JOIN VIP   v  ON v.CustomerID = o.CustomerID
		LEFT JOIN Rude  r  ON r.CustomerID = o.CustomerID;
	""")

	# ── View 2: Per-part cost breakdown (JOIN + arithmetic) ───────────────────
	db.query("""
		CREATE VIEW IF NOT EXISTS v_dress_cost_breakdown AS
		SELECT
			d.DressID,
			d.Dress_type,
			o.OrderID,
			c.Name AS Customer_Name,
			dp.Part_name,
			f.Fabric_type,
			f.Unit_cost,
			dp.Quantity_used,
			ROUND(f.Unit_cost * dp.Quantity_used, 2) AS Part_cost
		FROM Dress          d
		JOIN "Order"        o  ON o.OrderID    = d.OrderID
		JOIN Customer       c  ON c.CustomerID = o.CustomerID
		JOIN Dress_Parts   dp  ON dp.DressID   = d.DressID
		JOIN Fabric         f  ON f.FabricID   = dp.FabricID;
	""")

	# ── View 3: Top customers by total spending (subquery + aggregation) ──────
	db.query("""
		CREATE VIEW IF NOT EXISTS v_customer_spending AS
		SELECT
			c.CustomerID,
			c.Name,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE 'Normal'
			END AS Customer_Type,
			COUNT(o.OrderID) AS Total_orders,
			ROUND(SUM(o.Total_price), 2) AS Total_spent,
			ROUND(AVG(o.Total_price), 2) AS Avg_order_value
		FROM Customer c
		JOIN "Order" o ON o.CustomerID = c.CustomerID
		LEFT JOIN VIP v ON v.CustomerID = c.CustomerID
		LEFT JOIN Rude r ON r.CustomerID = c.CustomerID
		WHERE o.Order_status = 'Completed'
		GROUP BY c.CustomerID, c.Name;
	""")

	print("Database: Views created / verified.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 7 — PREFILL DATA (DML — Week 4)
#  Tables prefilled: Fabric, ShopItems, Machine, Player
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
		{"name": "Sewing Machine", "price": 500.0, "unlocked": true,  "in_use": true },
		{"name": "Cutting Table",  "price": 300.0, "unlocked": true,  "in_use": true },
		{"name": "Iron",           "price": 100.0, "unlocked": true,  "in_use": false},
		{"name": "Dress Form",     "price": 200.0, "unlocked": false, "in_use": false},
		{"name": "Display Rack",   "price": 150.0, "unlocked": false, "in_use": false},
	]
	for item in items:
		var unlock_s: String = "Unlocked"   if item["unlocked"] else "Locked"
		var use_s:    String = "In Use"     if item["in_use"]   else "Not In Use"
		db.query_with_bindings(
			"INSERT OR IGNORE INTO ShopItems (Item_name, Price, Unlock_Status, Use_Status) VALUES (?, ?, ?, ?);",
			[item["name"], item["price"], unlock_s, use_s]
		)

	# Machine record for the Sewing Machine (subclass of ShopItems)
	db.query("SELECT ItemID FROM ShopItems WHERE Item_name = 'Sewing Machine';")
	if not db.query_result.is_empty():
		var mid: int = db.query_result[0]["ItemID"]
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Machine (ItemID, Type, Speed) VALUES (?, ?, ?);",
			[mid, "Industrial", 5.0]
		)


func _prefill_player() -> void:
	db.query("SELECT COUNT(*) AS cnt FROM Player;")
	if db.query_result[0]["cnt"] == 0:
		db.query("INSERT INTO Player (Username, Level, Coins, Current_xp) VALUES ('Tailor', 1, 500, 0);")
		print("Database: Default player 'Tailor' created.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 8 — CUSTOMER FUNCTIONS
#  Implements the "name-first, DB-check, then generate" logic from the brief.
# ──────────────────────────────────────────────────────────────────────────────

## Returns a random name from NAME_POOL.
## Call this in berserkarmor._ready() to pick this customer's identity.
func get_random_name() -> String:
	return NAME_POOL[randi() % NAME_POOL.size()]


## Main entry point called by berserkarmor when the order UI is first opened.
##
## Workflow:
##   1. Check DB for a Customer row with this Name.
##   2. If found  → return their stored data (returning customer).
##   3. If not    → generate measurements/address from pools, INSERT, classify VIP/Rude.
##
## Returns a Dictionary with all Customer fields plus "customer_type" key.
func get_or_create_customer(name: String) -> Dictionary:
	# ── Step 1: Name lookup ───────────────────────────────────────────────────
	db.query_with_bindings(
		"SELECT * FROM Customer WHERE Name = ?;",
		[name]
	)

	if not db.query_result.is_empty():
		# ── Returning customer ─────────────────────────────────────────────────
		var customer: Dictionary = db.query_result[0].duplicate()
		active_customer_id       = customer["CustomerID"]
		customer["customer_type"] = _resolve_customer_type(active_customer_id)
		print("Database: Returning customer '%s' (ID=%d, Type=%s)."
			  % [name, active_customer_id, customer["customer_type"]])
		return customer

	else:
		# ── New customer — generate everything from pools ──────────────────────
		var generated: Dictionary = _generate_customer_record(name)
		_insert_full_customer(generated)
		generated["customer_type"] = _resolve_customer_type(active_customer_id)
		generated["CustomerID"]    = active_customer_id
		print("Database: New customer '%s' created (ID=%d, Type=%s)."
			  % [name, active_customer_id, generated["customer_type"]])
		return generated


func _resolve_customer_type(customer_id: int) -> String:
	db.query_with_bindings("SELECT CustomerID FROM VIP  WHERE CustomerID = ?;", [customer_id])
	if not db.query_result.is_empty():
		return "VIP"
	db.query_with_bindings("SELECT CustomerID FROM Rude WHERE CustomerID = ?;", [customer_id])
	if not db.query_result.is_empty():
		return "Rude"
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
	# Insert Customer row
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

	# Customer_Phone — generate a plausible Pakistani mobile number
	var phone: String = "03%01d%01d-%07d" % [
		randi() % 4,
		randi() % 10,
		randi() % 10000000
	]
	db.query_with_bindings(
		"INSERT INTO Customer_Phone (CustomerID, PhoneNo) VALUES (?, ?);",
		[active_customer_id, phone]
	)

	# ── Classify based on name: VIP / Rude / Normal ───────────────────────────
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

## Creates an Order record in DB the moment the player accepts a customer's order.
## Dress details are NOT known yet (chosen at cutting table) — they are attached later.
## Returns the new OrderID and stores it in active_order_id.
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


func _compute_receiving_date(customer_id: int) -> String:
	var total_days: int = BASE_RECEIVING_DAYS

	# Rude customers add their personal delay on top of the base window
	db.query_with_bindings(
		"SELECT Time_delay FROM Rude WHERE CustomerID = ?;",
		[customer_id]
	)
	if not db.query_result.is_empty():
		total_days += int(db.query_result[0]["Time_delay"])

	var future_unix: int  = int(Time.get_unix_time_from_system()) + (total_days * 86400)
	var dt:          Dictionary = Time.get_datetime_dict_from_unix_time(future_unix)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Called by cutting_table after the player selects dress, color, and fabric.
## Creates the Dress row + Dress_Color + all Dress_Parts for this order.
func attach_dress_to_order(
		order_id:     int,
		dress_display:String,   # e.g. "T-Shirt"  (stored in Dress.Dress_type)
		color:        String,   # e.g. "Navy Blue"
		fabric_type:  String    # e.g. "Cotton"   (resolved to FabricID)
) -> void:
	if order_id == -1:
		push_error("Database: attach_dress_to_order called with no active order!")
		return

	# ── Insert Dress row ──────────────────────────────────────────────────────
	db.query_with_bindings(
		"INSERT INTO Dress (OrderID, Dress_type) VALUES (?, ?);",
		[order_id, dress_display]
	)
	db.query("SELECT last_insert_rowid() AS id;")
	active_dress_id = int(db.query_result[0]["id"])

	# ── Insert Dress_Color ────────────────────────────────────────────────────
	db.query_with_bindings(
		"INSERT OR IGNORE INTO Dress_Color (DressID, Color) VALUES (?, ?);",
		[active_dress_id, color]
	)

	# ── Resolve FabricID ──────────────────────────────────────────────────────
	db.query_with_bindings(
		"SELECT FabricID FROM Fabric WHERE Fabric_type = ?;",
		[fabric_type]
	)
	if db.query_result.is_empty():
		push_error("Database: Fabric '%s' not found in DB!" % fabric_type)
		return
	var fabric_id: int = int(db.query_result[0]["FabricID"])

	# ── Insert Dress_Parts using template ────────────────────────────────────
	# Key: same normalization GameManager uses  ("T-Shirt" → "t-shirt")
	var key: String = dress_display.to_lower().replace(" ", "_")

	if not DRESS_PARTS_TEMPLATE.has(key):
		push_warning("Database: No parts template for '%s' (key='%s')." % [dress_display, key])
		return

	for part in DRESS_PARTS_TEMPLATE[key]:
		db.query_with_bindings("""
			INSERT OR IGNORE INTO Dress_Parts (DressID, Part_name, FabricID, Quantity_used)
			VALUES (?, ?, ?, ?);
		""", [active_dress_id, part[0], fabric_id, float(part[1])])
		# trg_deduct_fabric_stock fires automatically per part

	# Update Order status to Cutting
	db.query_with_bindings(
		"UPDATE \"Order\" SET Order_status = 'Cutting' WHERE OrderID = ?;",
		[order_id]
	)

	print("Database: Dress '%s' (%s, %s) attached to Order %d."
		  % [dress_display, color, fabric_type, order_id])


## Called by GameManager.complete_sewing() when the garment is fully sewn.
##
## THE IMPRESSIVE DERIVED ATTRIBUTE QUERY:
##   Computes Total_price via a correlated subquery that:
##     1. JOINs Dress → Dress_Parts → Fabric to sum (unit_cost × quantity)
##     2. Applies VIP discount via a correlated sub-subquery on the VIP table
##     3. Handles NULLs with COALESCE and rounds to 2 decimal places
##   Then sets Order_status = 'Completed'.
##   trg_order_auto_pay trigger then automatically sets Payment_status = 'Paid'.
func finalize_order(order_id: int) -> void:
	if order_id <= 0:
		order_id = active_order_id
	if order_id <= 0:
		push_error("Database: finalize_order() — no valid order ID!")
		return

	db.query_with_bindings("""
		UPDATE "Order"
		SET
		    Order_status = 'Completed',

		    Total_price = (
		        /*
		         * DERIVED ATTRIBUTE: Total_price
		         *
		         * Inner query:  Σ (Fabric.Unit_cost × Dress_Parts.Quantity_used)
		         *               for every part of every dress in this order.
		         *
		         * Correlated sub-subquery: fetch VIP.Discount_rate for this order's
		         *   customer (NULL → 0.0 via COALESCE), convert to a multiplier,
		         *   then deduct it from the raw sum.
		         *
		         * Uses: 2 INNER JOINs, 1 correlated subquery, COALESCE, ROUND.
		         */
		        SELECT ROUND(
		            COALESCE(SUM(f.Unit_cost * dp.Quantity_used), 0.0)
		            *
		            (1.0 - COALESCE(
		                (
		                    SELECT v.Discount_rate / 100.0
		                    FROM   VIP        v
							JOIN   "Order"    o_v ON o_v.CustomerID = v.CustomerID
		                    WHERE  o_v.OrderID = ?
		                ),
		                0.0
		            )),
		            2
		        )
		        FROM  Dress       d
		        JOIN  Dress_Parts dp  ON dp.DressID  = d.DressID
		        JOIN  Fabric       f  ON f.FabricID  = dp.FabricID
		        WHERE d.OrderID = ?
		    )

		WHERE OrderID = ?;
	""", [order_id, order_id, order_id])
	# ^ Three bindings for the three ? placeholders (order_id used 3 times)
	# Trigger trg_order_auto_pay fires and sets Payment_status = 'Paid'

	# Log the computed price
	db.query_with_bindings(
		"SELECT Total_price FROM \"Order\" WHERE OrderID = ?;",
		[order_id]
	)
	var price: float = 0.0
	if not db.query_result.is_empty():
		price = float(db.query_result[0]["Total_price"])

	print("Database: Order %d finalized. Total price = %.2f coins." % [order_id, price])
	active_order_id = -1
	active_dress_id = -1


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 10 — PLAYER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

## Adds XP and Coins to the single player (PlayerID = 1).
## The trg_player_level_up trigger handles Level recalculation automatically.
func add_player_rewards(xp: int, coins: int) -> void:
	db.query_with_bindings("""
		UPDATE Player
		SET Current_xp = Current_xp + ?,
		    Coins      = Coins      + ?
		WHERE PlayerID = 1;
	""", [xp, coins])
	print("Database: Player rewarded +%d XP, +%d coins." % [xp, coins])


## Returns the player's full stats with a computed "xp_to_next_level" column.
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

## Full order details for a given OrderID using the summary view.
func get_order_details(order_id: int) -> Dictionary:
	db.query_with_bindings(
		"SELECT * FROM v_order_summary WHERE OrderID = ?;",
		[order_id]
	)
	if db.query_result.is_empty():
		return {}
	return db.query_result[0].duplicate()


## Per-part cost breakdown for a given DressID.
func get_dress_cost_breakdown(dress_id: int) -> Array:
	db.query_with_bindings(
		"SELECT * FROM v_dress_cost_breakdown WHERE DressID = ?;",
		[dress_id]
	)
	return db.query_result.duplicate()


## All completed orders newest-first — used for a history screen.
func get_order_history() -> Array:
	db.query("SELECT * FROM v_order_summary WHERE Order_status = 'Completed' ORDER BY OrderID DESC;")
	return db.query_result.duplicate()


## Total earnings across all completed orders.
func get_total_earnings() -> float:
	db.query("""
		SELECT ROUND(COALESCE(SUM(Total_price), 0.0), 2) AS earnings
		FROM "Order"
		WHERE Order_status = 'Completed';
	""")
	if db.query_result.is_empty():
		return 0.0
	var val = db.query_result[0]["earnings"]
	return 0.0 if val == null else float(val)


## VIP discount % for a customer (0.0 if not VIP).
func get_vip_discount(customer_id: int) -> float:
	db.query_with_bindings(
		"SELECT Discount_rate FROM VIP WHERE CustomerID = ?;",
		[customer_id]
	)
	if db.query_result.is_empty():
		return 0.0
	return float(db.query_result[0]["Discount_rate"])


## Rude delay days for a customer (0 if not Rude).
func get_rude_delay(customer_id: int) -> int:
	db.query_with_bindings(
		"SELECT Time_delay FROM Rude WHERE CustomerID = ?;",
		[customer_id]
	)
	if db.query_result.is_empty():
		return 0
	return int(db.query_result[0]["Time_delay"])


## Fabric unit cost by name (used for UI price previews).
func get_fabric_cost(fabric_type: String) -> float:
	db.query_with_bindings(
		"SELECT Unit_cost FROM Fabric WHERE Fabric_type = ?;",
		[fabric_type]
	)
	if db.query_result.is_empty():
		return 0.0
	return float(db.query_result[0]["Unit_cost"])


## Top customers by total spend — useful for a leaderboard or stats screen.
## Uses v_customer_spending view (subquery + GROUP BY + aggregate).
func get_top_customers(limit: int = 5) -> Array:
	db.query_with_bindings(
		"SELECT * FROM v_customer_spending ORDER BY Total_spent DESC LIMIT ?;",
		[limit]
	)
	return db.query_result.duplicate()
