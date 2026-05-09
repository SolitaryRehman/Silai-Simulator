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

const HOUSE_POOL: Array  = ["12-A","45-B","7-C","88","3/4","22-D","101","56-F","9-G","77"]
const STREET_POOL: Array = [
	"Gulshan Street","Model Town Road","Saddar Lane","Cavalry Boulevard",
	"F-7 Street","I-8 Road","DHA Avenue","Bahria Road","PWD Road","Peshawar Road"
]
const SECTOR_POOL: Array = [
	"G-9","F-7","I-8","DHA Phase 2","Bahria Phase 5",
	"Gulshan-e-Iqbal","Model Town","Cantt","Satellite Town","Askari-14"
]
const CITY_POOL: Array = [
	"Islamabad","Rawalpindi","Lahore","Karachi","Peshawar","Quetta"
]

const COLLAR_RANGE:   Array = [13, 18]
const CHEST_RANGE:    Array = [32, 48]
const SHOULDER_RANGE: Array = [14, 20]
const SLEEVE_RANGE:   Array = [22, 28]
const TROUSER_RANGE:  Array = [36, 46]
const WAIST_RANGE:    Array = [28, 44]

const VIP_DISCOUNT_RANGE: Array = [10, 25]
const RUDE_DELAY_RANGE:   Array = [1,   4]
const BASE_RECEIVING_DAYS: int  = 3

const DRESS_POOL: Array = [
	"T-Shirt","Frock","Bishop Gown","Pants","Jacket","Maxi","Lehenga"
]
const FABRIC_POOL: Array = [
	"Cotton","Silk","Linen","Polyester","Lawn","Chiffon","Denim"
]
const COLOR_POOL: Array = [
	"Navy Blue","Crimson Red","Forest Green","Pearl White",
	"Jet Black","Purple","Golden","Sky Blue"
]

# XP / coin ranges per number of dresses in one order
const XP_RANGES: Dictionary   = { 1: [50, 120],  2: [130, 250], 3: [260, 400] }
const COIN_RANGES: Dictionary = { 1: [100, 300], 2: [320, 550], 3: [570, 900] }

# DRESS_PARTS_TEMPLATE — keys must match dress_display.to_lower().replace(" ","_")
# Each entry: [part_name, quantity_metres]
# Each part will get its OWN randomly assigned fabric + color (fixes 1:M / M:M violations).
const DRESS_PARTS_TEMPLATE: Dictionary = {
	"t-shirt":     [["Front Panel",1.5],["Back Panel",1.5],["Sleeve",0.5],["Collar",0.2]],
	"frock":       [["Bodice",1.0],["Skirt",2.0],["Sleeve",0.5],["Neckband",0.3]],
	"bishop_gown": [["Bodice",1.2],["Skirt",2.5],["Bishop Sleeve",0.8],["Collar",0.3]],
	"pants":       [["Front Panel",1.5],["Back Panel",1.5],["Waistband",0.3],["Pocket",0.2]],
	"jacket":      [["Front Panel",1.2],["Back Panel",1.2],["Sleeve",0.7],["Lining",0.8]],
	"maxi":        [["Bodice",1.0],["Skirt",3.0],["Sleeve",0.5],["Hem",0.3]],
	"lehenga":     [["Skirt",2.5],["Blouse",1.0],["Dupatta",2.0],["Waistband",0.3]],
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
	_create_tables()       # CREATE IF NOT EXISTS — new schema, no Total_price
	_migrate_database()    # CHANGE 1+4: remove Total_price, update status values
	_drop_triggers()       # Always regenerate so they stay current
	_create_triggers()
	_drop_views()          # Always regenerate so calculated-price view stays current
	_create_views()
	_prefill_data()
	print("═══ Database: Fully initialized. ═══")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_db()


func _open_db() -> void:
	db = SQLite.new()
	db.path            = DB_PATH
	db.verbosity_level = SQLite.QUIET
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
			              CHECK(Unlock_Status IN ('Locked','Unlocked')),
			Use_Status    TEXT    NOT NULL DEFAULT 'Not In Use'
			              CHECK(Use_Status IN ('In Use','Not In Use'))
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

	# CHANGE 1: Order_status is now Pending → Completed → Delivered only.
	# CHANGE 4: Total_price is a DERIVED ATTRIBUTE — not stored here, computed on demand.
	db.query("""
		CREATE TABLE IF NOT EXISTS "Order" (
			OrderID         INTEGER PRIMARY KEY AUTOINCREMENT,
			CustomerID      INTEGER NOT NULL,
			Order_date      TEXT    NOT NULL,
			Receiving_date  TEXT    NOT NULL,
			Payment_status  TEXT    NOT NULL DEFAULT 'Unpaid'
			                CHECK(Payment_status IN ('Unpaid','Paid')),
			Order_status    TEXT    NOT NULL DEFAULT 'Pending'
			                CHECK(Order_status IN ('Pending','Completed','Delivered')),
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
	# CHANGE 6: Dress_Color is 1:M — a dress can have MULTIPLE colors (one per part).
	db.query("""
		CREATE TABLE IF NOT EXISTS Dress_Color (
			DressID  INTEGER NOT NULL,
			Color    TEXT    NOT NULL,
			PRIMARY KEY (DressID, Color),
			FOREIGN KEY (DressID) REFERENCES Dress(DressID)
			ON DELETE CASCADE ON UPDATE CASCADE
		);
	""")
	# CHANGE 6: Dress_Parts is M:M(Dress×Fabric) — each part has its OWN fabric.
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
#  SECTION 4b — MIGRATION
#  CHANGE 1+4: Removes legacy Total_price column and maps old order statuses.
# ──────────────────────────────────────────────────────────────────────────────

func _migrate_database() -> void:
	# Detect whether the old Order table still has a Total_price column
	db.query("PRAGMA table_info(\"Order\");")
	var has_total_price := false
	for col in db.query_result:
		if col["name"] == "Total_price":
			has_total_price = true
			break

	if not has_total_price:
		return   # Already on current schema — nothing to do

	print("Database: Migrating Order table (removing Total_price, updating statuses)...")

	# FK must be off while we swap tables
	db.query("PRAGMA foreign_keys = OFF;")

	# New table without Total_price, with updated CHECK constraint
	db.query("""
		CREATE TABLE "Order_new" (
			OrderID         INTEGER PRIMARY KEY AUTOINCREMENT,
			CustomerID      INTEGER NOT NULL,
			Order_date      TEXT    NOT NULL,
			Receiving_date  TEXT    NOT NULL,
			Payment_status  TEXT    NOT NULL DEFAULT 'Unpaid'
			                CHECK(Payment_status IN ('Unpaid','Paid')),
			Order_status    TEXT    NOT NULL DEFAULT 'Pending'
			                CHECK(Order_status IN ('Pending','Completed','Delivered')),
			FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
		);
	""")

	# Copy rows, mapping legacy statuses to the new three-state model
	db.query("""
		INSERT INTO "Order_new"
		    (OrderID, CustomerID, Order_date, Receiving_date, Payment_status, Order_status)
		SELECT
		    OrderID, CustomerID, Order_date, Receiving_date, Payment_status,
		    CASE Order_status
		        WHEN 'Cutting'   THEN 'Pending'
		        WHEN 'Sewing'    THEN 'Pending'
		        WHEN 'Cancelled' THEN 'Completed'
		        WHEN 'Completed' THEN 'Completed'
		        WHEN 'Delivered' THEN 'Delivered'
		        ELSE                  'Pending'
		    END
		FROM "Order";
	""")

	db.query("DROP TABLE \"Order\";")
	db.query("ALTER TABLE \"Order_new\" RENAME TO \"Order\";")
	db.query("PRAGMA foreign_keys = ON;")
	print("Database: Migration complete.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 5 — TRIGGERS
# ──────────────────────────────────────────────────────────────────────────────

func _drop_triggers() -> void:
	db.query("DROP TRIGGER IF EXISTS trg_player_level_up;")
	db.query("DROP TRIGGER IF EXISTS trg_deduct_fabric_stock;")


func _create_triggers() -> void:
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
	# Auto-deduct fabric stock each time a dress part is inserted
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
	print("Database: Triggers created / verified.")


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 6 — VIEWS
#  CHANGE 4: Total_price is now always CALCULATED from Dress_Parts × Fabric,
#  never read from a stored column. All three views reflect this.
# ──────────────────────────────────────────────────────────────────────────────

func _drop_views() -> void:
	db.query("DROP VIEW IF EXISTS v_order_summary;")
	db.query("DROP VIEW IF EXISTS v_dress_cost_breakdown;")
	db.query("DROP VIEW IF EXISTS v_customer_spending;")


func _create_views() -> void:
	# CHANGE 4: Calculated_price replaces the old stored Total_price column.
	db.query("""
		CREATE VIEW IF NOT EXISTS v_order_summary AS
		SELECT
			o.OrderID,
			c.Name                              AS Customer_Name,
			c.City,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE                               'Normal'
			END                                 AS Customer_Type,
			COALESCE(v.Discount_rate, 0)        AS Discount_pct,
			COALESCE(r.Time_delay,    0)        AS Delay_days,
			d.Dress_type,
			GROUP_CONCAT(DISTINCT dc.Color)     AS Colors,
			o.Order_date,
			o.Receiving_date,
			o.Order_status,
			o.Payment_status,
			ROUND(
				COALESCE((
					SELECT SUM(f2.Unit_cost * dp2.Quantity_used)
					FROM   Dress     d2
					JOIN   Dress_Parts dp2 ON dp2.DressID  = d2.DressID
					JOIN   Fabric     f2  ON  f2.FabricID  = dp2.FabricID
					WHERE  d2.OrderID = o.OrderID
				), 0.0)
				* (1.0 - COALESCE(v.Discount_rate, 0.0) / 100.0),
			2)                                  AS Calculated_price
		FROM "Order"    o
		JOIN  Customer  c  ON c.CustomerID = o.CustomerID
		JOIN  Dress     d  ON d.OrderID    = o.OrderID
		LEFT JOIN Dress_Color dc ON dc.DressID   = d.DressID
		LEFT JOIN VIP   v  ON v.CustomerID = o.CustomerID
		LEFT JOIN Rude  r  ON r.CustomerID = o.CustomerID
		GROUP BY o.OrderID, d.DressID;
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
	# CHANGE 4: Total_spent and Avg_order_value computed from parts — no stored Total_price.
	db.query("""
		CREATE VIEW IF NOT EXISTS v_customer_spending AS
		SELECT
			c.CustomerID,
			c.Name,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE                               'Normal'
			END                                                       AS Customer_Type,
			COUNT(DISTINCT o.OrderID)                                 AS Total_orders,
			ROUND(COALESCE(SUM(
				f.Unit_cost * dp.Quantity_used *
				(1.0 - COALESCE(
					(SELECT v2.Discount_rate / 100.0 FROM VIP v2
					 WHERE v2.CustomerID = c.CustomerID),
					0.0
				))
			), 0.0), 2)                                               AS Total_spent,
			ROUND(COALESCE(SUM(
				f.Unit_cost * dp.Quantity_used *
				(1.0 - COALESCE(
					(SELECT v2.Discount_rate / 100.0 FROM VIP v2
					 WHERE v2.CustomerID = c.CustomerID),
					0.0
				))
			) / NULLIF(COUNT(DISTINCT o.OrderID), 0), 0.0), 2)       AS Avg_order_value
		FROM Customer   c
		JOIN "Order"    o  ON o.CustomerID  = c.CustomerID
		JOIN Dress      d  ON d.OrderID     = o.OrderID
		JOIN Dress_Parts dp ON dp.DressID   = d.DressID
		JOIN Fabric     f  ON  f.FabricID   = dp.FabricID
		LEFT JOIN VIP   v  ON  v.CustomerID = c.CustomerID
		LEFT JOIN Rude  r  ON  r.CustomerID = c.CustomerID
		WHERE o.Order_status IN ('Completed','Delivered')
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
		{"type":"Cotton",    "cost":50.0,  "stock":100},
		{"type":"Silk",      "cost":150.0, "stock":50 },
		{"type":"Linen",     "cost":80.0,  "stock":75 },
		{"type":"Polyester", "cost":40.0,  "stock":120},
		{"type":"Lawn",      "cost":60.0,  "stock":90 },
		{"type":"Chiffon",   "cost":120.0, "stock":60 },
		{"type":"Denim",     "cost":90.0,  "stock":80 },
	]
	for f in fabrics:
		db.query_with_bindings(
			"INSERT OR IGNORE INTO Fabric (Fabric_type, Unit_cost, Stock_quantity) VALUES (?, ?, ?);",
			[f["type"], f["cost"], f["stock"]]
		)


func _prefill_shop_items() -> void:
	var items: Array = [
		{"name":"Embroidery Machine",  "price":1000.0, "unlocked":false, "in_use":false},
		{"name":"Overlocking Machine", "price":2500.0, "unlocked":false, "in_use":false},
		{"name":"Desi Machine",        "price":500.0,  "unlocked":true,  "in_use":true },
		{"name":"Cutting Table",       "price":300.0,  "unlocked":true,  "in_use":true },
		{"name":"Iron",                "price":100.0,  "unlocked":true,  "in_use":false},
		{"name":"Dress Form",          "price":200.0,  "unlocked":false, "in_use":false},
		{"name":"Display Rack",        "price":150.0,  "unlocked":false, "in_use":false},
	]
	for item in items:
		var unlock_s: String = "Unlocked" if item["unlocked"] else "Locked"
		var use_s:    String = "In Use"   if item["in_use"]   else "Not In Use"
		db.query_with_bindings(
			"INSERT OR IGNORE INTO ShopItems (Item_name, Price, Unlock_Status, Use_Status) VALUES (?, ?, ?, ?);",
			[item["name"], item["price"], unlock_s, use_s]
		)
	var machines: Array = [
		{"name":"Embroidery Machine",  "type":"Electrical", "speed":10.0},
		{"name":"Overlocking Machine", "type":"Electrical", "speed":15.0},
		{"name":"Desi Machine",        "type":"Mechanical", "speed":2.0 },
	]
	for machine in machines:
		db.query_with_bindings("SELECT ItemID FROM ShopItems WHERE Item_name = ?;", [machine["name"]])
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

## Step 1 of Accept flow: create the Order row. Returns new OrderID.
func create_order_record(customer_id: int) -> int:
	var order_date:     String = Time.get_datetime_string_from_system()
	var receiving_date: String = _compute_receiving_date(customer_id)
	db.query_with_bindings("""
		INSERT INTO "Order"
		    (CustomerID, Order_date, Receiving_date, Payment_status, Order_status)
		VALUES (?, ?, ?, 'Unpaid', 'Pending');
	""", [customer_id, order_date, receiving_date])
	db.query("SELECT last_insert_rowid() AS id;")
	active_order_id = int(db.query_result[0]["id"])
	print("Database: Order %d created (Customer %d, due %s)."
		  % [active_order_id, customer_id, receiving_date])
	return active_order_id


func _compute_receiving_date(customer_id: int) -> String:
	var total_days: int  = BASE_RECEIVING_DAYS + get_rude_delay(customer_id)
	var future_unix: int = int(Time.get_unix_time_from_system()) + (total_days * 86400)
	var dt: Dictionary   = Time.get_datetime_dict_from_unix_time(future_unix)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## Step 2 of Accept flow: insert all dresses with per-part fabrics and colors.
## CHANGE 6: each part in each dress gets its own randomly assigned fabric + color.
func attach_all_dresses_to_order(order_id: int, order_data: Dictionary) -> void:
	var dresses: Array = order_data.get("dresses", [])
	if dresses.is_empty():
		push_warning("Database: attach_all_dresses_to_order — no dresses in order dict!")
		return
	for dress_dict in dresses:
		_attach_single_dress(order_id, dress_dict)
	print("Database: %d dress(es) attached to Order %d." % [dresses.size(), order_id])


## Internal — inserts one Dress + per-part Dress_Parts + unique Dress_Colors.
## CHANGE 6: dress_dict["parts"] is an array of {part_name, fabric, color, quantity}.
func _attach_single_dress(order_id: int, dress_dict: Dictionary) -> void:
	var dress_display: String = dress_dict.get("dress", "T-Shirt")

	db.query_with_bindings(
		"INSERT INTO Dress (OrderID, Dress_type) VALUES (?, ?);",
		[order_id, dress_display]
	)
	db.query("SELECT last_insert_rowid() AS id;")
	active_dress_id = int(db.query_result[0]["id"])

	var parts: Array             = dress_dict.get("parts", [])
	var inserted_colors: Dictionary = {}   # deduplicate Dress_Color inserts

	for part in parts:
		# --- Dress_Color (1:M — multiple colors per dress) ---
		var color: String = part.get("color", "Navy Blue")
		if not inserted_colors.has(color):
			db.query_with_bindings(
				"INSERT OR IGNORE INTO Dress_Color (DressID, Color) VALUES (?, ?);",
				[active_dress_id, color]
			)
			inserted_colors[color] = true

		# --- Fabric lookup (M:M — each part has its own fabric) ---
		var fabric_type: String = part.get("fabric", "Cotton")
		db.query_with_bindings(
			"SELECT FabricID FROM Fabric WHERE Fabric_type = ?;",
			[fabric_type]
		)
		if db.query_result.is_empty():
			push_error("Database: Fabric '%s' not found — using Cotton fallback." % fabric_type)
			db.query("SELECT FabricID FROM Fabric WHERE Fabric_type = 'Cotton';")
			if db.query_result.is_empty():
				continue
		var fabric_id: int = int(db.query_result[0]["FabricID"])

		# --- Dress_Parts: each part row has its own FabricID ---
		db.query_with_bindings("""
			INSERT OR IGNORE INTO Dress_Parts (DressID, Part_name, FabricID, Quantity_used)
			VALUES (?, ?, ?, ?);
		""", [active_dress_id, part.get("part_name", "Part"), fabric_id, float(part.get("quantity", 1.0))])
		# trg_deduct_fabric_stock fires automatically per INSERT above


## CHANGE 1: Only valid statuses are 'Pending', 'Completed', 'Delivered'.
## Called by GameManager at workflow stage transitions.
func update_order_status(order_id: int, new_status: String) -> void:
	if not new_status in ["Pending", "Completed", "Delivered"]:
		push_warning("Database: Invalid order status '%s' — ignored." % new_status)
		return
	db.query_with_bindings(
		"UPDATE \"Order\" SET Order_status = ? WHERE OrderID = ?;",
		[new_status, order_id]
	)


## CHANGE 4: Derived attribute — total price computed from Dress_Parts × Fabric costs.
## Called right after attach_all_dresses_to_order() to show player the price on accept.
## Applies VIP discount via correlated subquery.  Returns 0.0 if no parts found.
func calculate_order_price(order_id: int) -> float:
	db.query_with_bindings("""
		SELECT ROUND(
			COALESCE(SUM(f.Unit_cost * dp.Quantity_used), 0.0)
			* (1.0 - COALESCE(
				(SELECT v.Discount_rate / 100.0
				 FROM   VIP      v
				 JOIN   "Order"  o_v ON o_v.CustomerID = v.CustomerID
				 WHERE  o_v.OrderID = ?),
				0.0
			)),
			2
		) AS price
		FROM  Dress       d
		JOIN  Dress_Parts dp ON dp.DressID  = d.DressID
		JOIN  Fabric       f ON  f.FabricID = dp.FabricID
		WHERE d.OrderID = ?;
	""", [order_id, order_id])
	if db.query_result.is_empty() or db.query_result[0]["price"] == null:
		return 0.0
	return float(db.query_result[0]["price"])


## CHANGE 1: Sets Order_status to 'Completed' (no more intermediate states).
## CHANGE 4: No Total_price is stored — it is always derived on demand.
func finalize_order(order_id: int) -> void:
	if order_id <= 0:
		push_error("Database: finalize_order() — invalid order_id: %d" % order_id)
		return
	db.query_with_bindings(
		"UPDATE \"Order\" SET Order_status = 'Completed' WHERE OrderID = ?;",
		[order_id]
	)
	var price: float = calculate_order_price(order_id)
	print("Database: Order %d finalized → Completed. Calculated price = %.2f coins." % [order_id, price])


## CHANGE 3: Marks a single order as Delivered + Paid.
func deliver_order(order_id: int) -> void:
	db.query_with_bindings("""
		UPDATE "Order"
		SET    Order_status   = 'Delivered',
		       Payment_status = 'Paid'
		WHERE  OrderID      = ?
		  AND  Order_status = 'Completed';
	""", [order_id])
	print("Database: Order %d → Delivered / Paid." % order_id)


## CHANGE 3: Delivers ALL completed-unpaid orders in a given Sector+City.
## Returns a dict {count, revenue} for the HUD feedback label.
func deliver_orders_for_area(city: String) -> Dictionary:
	# First aggregate the revenue (derived from parts) before updating
	db.query_with_bindings("""
		SELECT
			COUNT(DISTINCT o.OrderID) AS order_count,
			ROUND(COALESCE(SUM(
				f.Unit_cost * dp.Quantity_used *
				(1.0 - COALESCE(
					(SELECT v.Discount_rate / 100.0 FROM VIP v WHERE v.CustomerID = o.CustomerID),
					0.0
				))
			), 0.0), 2) AS total_revenue
		FROM "Order"   o
		JOIN Customer  c  ON c.CustomerID = o.CustomerID
		JOIN Dress     d  ON d.OrderID    = o.OrderID
		JOIN Dress_Parts dp ON dp.DressID = d.DressID
		JOIN Fabric    f  ON  f.FabricID  = dp.FabricID
		WHERE c.City = ?
		  AND o.Order_status   = 'Completed'
		  AND o.Payment_status = 'Unpaid';
	""", [city])

	var count: int    = 0
	var revenue: float = 0.0
	if not db.query_result.is_empty():
		count   = int(db.query_result[0]["order_count"])
		var raw = db.query_result[0]["total_revenue"]
		revenue = 0.0 if raw == null else float(raw)

	if count == 0:
		return {"count": 0, "revenue": 0.0}

	# Now mark all matching orders as Delivered + Paid
	db.query_with_bindings("""
		UPDATE "Order"
		SET    Order_status   = 'Delivered',
		       Payment_status = 'Paid'
		WHERE  OrderID IN (
			SELECT o2.OrderID FROM "Order" o2
			JOIN   Customer c2 ON c2.CustomerID = o2.CustomerID
			WHERE c2.City = ?
			  AND  o2.Order_status   = 'Completed'
			  AND  o2.Payment_status = 'Unpaid'
		);
	""", [city])

	print("Database: Dispatched %d order(s) to %s — Revenue %.2f coins."
		  % [count, city, revenue])
	return {"count": count, "revenue": revenue}


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 10 — PLAYER FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

func add_player_rewards(xp: int, coins: int) -> void:
	db.query_with_bindings("""
		UPDATE Player
		SET Current_xp = Current_xp + ?,
		    Coins      = Coins      + ?
		WHERE PlayerID = 1;
	""", [xp, coins])
	print("Database: Player rewarded +%d XP, +%d coins." % [xp, coins])


func get_player_data() -> Dictionary:
	db.query("""
		SELECT
			PlayerID, Username, Level, Coins, Current_xp,
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

## CHANGE 6: Each dress now carries a "parts" array with per-part fabric + color.
## This is the SINGLE SOURCE OF TRUTH for all order randomization.
func generate_random_dress_order(customer_name: String) -> Dictionary:
	var num_dresses: int = randi_range(1, 3)
	var dresses: Array   = []
	var total_metres: float = 0.0

	for _i in range(num_dresses):
		var dress_type: String = DRESS_POOL[randi() % DRESS_POOL.size()]
		var key: String        = dress_type.to_lower().replace(" ", "_")
		var template: Array    = DRESS_PARTS_TEMPLATE.get(key, [])

		var parts: Array = []
		for p in template:
			var fabric: String = FABRIC_POOL[randi() % FABRIC_POOL.size()]
			var color:  String = COLOR_POOL[randi()  % COLOR_POOL.size()]
			parts.append({
				"part_name": p[0],
				"quantity":  p[1],
				"fabric":    fabric,
				"color":     color,
			})
			total_metres += float(p[1])

		dresses.append({
			"dress": dress_type,
			"parts": parts,
		})

	var xp_range:   Array = XP_RANGES[num_dresses]
	var coin_range: Array = COIN_RANGES[num_dresses]
	return {
		"customer_name": customer_name,
		"dresses":       dresses,
		"fabric_used":   "%.1f m total" % total_metres,   # informational display string
		"xp_reward":     randi_range(xp_range[0],   xp_range[1]),
		"coin_reward":   randi_range(coin_range[0],  coin_range[1]),  # overridden by calculate_order_price after DB insert
		"timestamp":     Time.get_datetime_string_from_system(),
		"status":        "pending"
	}


## CHANGE 2+5: Returns full dress breakdown for a given order from DB.
## Used by GameManager for session persistence and for the dress-by-dress cutting loop.
func get_dresses_for_order(order_id: int) -> Array:
	db.query_with_bindings("""
		SELECT
			d.DressID,
			d.Dress_type,
			GROUP_CONCAT(DISTINCT dc.Color)      AS Colors,
			GROUP_CONCAT(DISTINCT f.Fabric_type) AS Fabrics,
			COUNT(DISTINCT dp.Part_name)         AS Part_count
		FROM Dress      d
		LEFT JOIN Dress_Color  dc ON dc.DressID  = d.DressID
		LEFT JOIN Dress_Parts  dp ON dp.DressID  = d.DressID
		LEFT JOIN Fabric        f ON  f.FabricID = dp.FabricID
		WHERE d.OrderID = ?
		GROUP BY d.DressID, d.Dress_type
		ORDER BY d.DressID ASC;
	""", [order_id])
	return db.query_result.duplicate()


func get_vip_discount(customer_id: int) -> float:
	db.query_with_bindings(
		"SELECT Discount_rate FROM VIP WHERE CustomerID = ?;",
		[customer_id]
	)
	if db.query_result.is_empty(): return 0.0
	return float(db.query_result[0]["Discount_rate"])


func get_rude_delay(customer_id: int) -> int:
	db.query_with_bindings(
		"SELECT Time_delay FROM Rude WHERE CustomerID = ?;",
		[customer_id]
	)
	if db.query_result.is_empty(): return 0
	return int(db.query_result[0]["Time_delay"])


## CHANGE 1+2: Returns orders with status 'Pending' — used for cutting table selection
## and session persistence (CHANGE 5).
func get_pending_orders() -> Array:
	db.query("""
		SELECT
			o.OrderID,
			c.Name                             AS Customer_Name,
			c.City,
			GROUP_CONCAT(d.Dress_type, ', ')   AS Dresses,
			COUNT(d.DressID)                   AS Dress_count,
			o.Order_date,
			o.Receiving_date,
			o.Order_status,
			CASE
				WHEN v.CustomerID IS NOT NULL THEN 'VIP'
				WHEN r.CustomerID IS NOT NULL THEN 'Rude'
				ELSE                               'Normal'
			END                                AS Customer_Type
		FROM "Order"    o
		JOIN  Customer  c  ON c.CustomerID = o.CustomerID
		LEFT JOIN Dress d  ON d.OrderID    = o.OrderID
		LEFT JOIN VIP   v  ON v.CustomerID = o.CustomerID
		LEFT JOIN Rude  r  ON r.CustomerID = o.CustomerID
		WHERE o.Order_status = 'Pending'
		GROUP BY o.OrderID
		ORDER BY o.OrderID ASC;
	""")
	return db.query_result.duplicate()


## CHANGE 3: Top areas with completed-but-undelivered orders.
## CHANGE 4: Revenue is derived from Dress_Parts × Fabric (no stored Total_price).
func get_top_delivery_areas(limit: int = 5) -> Array:
	db.query_with_bindings("""
		SELECT
			c.City,
			COUNT(DISTINCT o.OrderID)  AS Pending_deliveries,
			ROUND(COALESCE(SUM(
				f.Unit_cost * dp.Quantity_used *
				(1.0 - COALESCE(
					(SELECT v.Discount_rate / 100.0 FROM VIP v
					 WHERE v.CustomerID = o.CustomerID),
					0.0
				))
			), 0.0), 2)                AS Area_revenue
		FROM "Order"     o
		JOIN Customer    c  ON c.CustomerID = o.CustomerID
		JOIN Dress       d  ON d.OrderID    = o.OrderID
		JOIN Dress_Parts dp ON dp.DressID   = d.DressID
		JOIN Fabric      f  ON  f.FabricID  = dp.FabricID
		WHERE o.Order_status   = 'Completed'
		  AND o.Payment_status = 'Unpaid'
		GROUP BY c.City
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


## CHANGE 1: Includes both Completed and Delivered in history.
func get_order_history() -> Array:
	db.query("""
		SELECT * FROM v_order_summary
		WHERE Order_status IN ('Completed','Delivered')
		ORDER BY OrderID DESC;
	""")
	return db.query_result.duplicate()


## CHANGE 4: Earnings derived from parts — no stored Total_price.
func get_total_earnings() -> float:
	db.query("""
		SELECT ROUND(COALESCE(SUM(
			f.Unit_cost * dp.Quantity_used *
			(1.0 - COALESCE(
				(SELECT v.Discount_rate / 100.0 FROM VIP v WHERE v.CustomerID = o.CustomerID),
				0.0
			))
		), 0.0), 2) AS earnings
		FROM "Order"     o
		JOIN Dress       d  ON d.OrderID    = o.OrderID
		JOIN Dress_Parts dp ON dp.DressID   = d.DressID
		JOIN Fabric      f  ON  f.FabricID  = dp.FabricID
		WHERE o.Order_status IN ('Completed','Delivered');
	""")
	return float(db.query_result[0]["earnings"])


func get_top_customers(limit: int = 5) -> Array:
	db.query_with_bindings(
		"SELECT * FROM v_customer_spending ORDER BY Total_spent DESC LIMIT ?;",
		[limit]
	)
	return db.query_result.duplicate()
