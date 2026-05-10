<div align="center">

# 🧵 Silai Simulator

### A 3D Tailoring & Shop Simulation Game

*Built with Godot Engine · GDScript · SQLite*

![Godot](https://img.shields.io/badge/Godot-4.x-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-Native-3a7bd5?style=for-the-badge)
![SQLite](https://img.shields.io/badge/SQLite-Database-003B57?style=for-the-badge&logo=sqlite&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-Version%20Control-181717?style=for-the-badge&logo=github)

> **CS-220 Database Systems — Semester Project Spring 2026**
> BSCS-15-E | Abdul Rehman Riaz · Muhammad Uzair Khan · Muhammad Musa Toor · Hashim Abdullah

</div>

---

## 📋 Table of Contents

1. [Project Overview](#-project-overview)
2. [Technologies Used](#-technologies-used)
3. [Database Integration](#-database-integration)
4. [DBMS Concepts Applied](#-dbms-concepts-applied)
5. [Database Schema & Relationships](#-database-schema--relationships)
6. [Workflow Architecture](#-workflow-architecture)
7. [Functional Flow](#-functional-flow)
8. [File Structure](#-file-structure)
9. [Advanced Query System](#-advanced-query-system)
10. [Software Engineering Concepts](#-software-engineering-concepts)

---

## 🎮 Project Overview

**Silai Simulator** is a fully 3D shop simulation game built in **Godot Engine**, where the player steps into the role of a tailor managing a real tailoring business. Customers walk through the door of a fully rendered 3D shop, place clothing orders with custom measurements, and the player must navigate the environment — moving between the cutting table, sewing machine, and delivery counter — to complete orders and grow the business.

Every piece of data in the game — customers, measurements, orders, fabrics, dress parts, machine unlocks, and player progression — is stored, retrieved, and manipulated through a **relational SQLite database**, making this project a practical, full-scale demonstration of DBMS concepts embedded inside a real game.

### 3D Gameplay Environment

Unlike a typical 2D simulation, Silai Simulator places the player inside a **fully navigable 3D tailoring shop**. The camera moves through the space, customers are animated 3D characters with walk cycles, and every workstation — the cutting table, the sewing machine, the delivery counter — is a physical object the player interacts with in 3D space. Every interaction maps directly to a database transaction in the backend.

### Gameplay Loop

```
Customer walks into the 3D shop (animated character)
             ↓
Order placed at the counter — clothing type, colors, measurements recorded
             ↓
Player moves to the cutting table → selects fabric from inventory
             ↓
Dress parts (collar, body, sleeves, ...) assembled using the sewing machine
             ↓
Completed dress delivered to customer
             ↓
Coins + XP awarded → Player levels up → Machines & ShopItems unlock
             ↓
Shop expands, orders get harder, cycle continues
```

### Core Systems

| System | Description |
|---|---|
| **Customer Generation** | 3D characters with full measurement profiles: collar size, chest, shoulder, sleeve length, trouser length, waist |
| **Order Management** | Each order tracks dress type, assigned fabrics, order/receiving dates, payment status, and completion status (`Pending` → `Completed` → `Delivered`) |
| **Dress & Parts System** | Each dress is composed of named parts (e.g. collar, body, sleeves); each part has its own fabric and color. `Total_price` is a **derived attribute** computed from `Dress_Parts × Fabric` costs |
| **VIP & Rude Customers** | Customer specialization — VIP customers get automatic discounts; Rude customers impose time penalties on the receiving date |
| **Inventory System** | Fabrics tracked with type, unit cost, and stock quantity; stock depletes automatically via trigger each time a dress part is inserted |
| **Reward & Progression** | Orders earn Coins and XP; a trigger auto-calculates the player's level from accumulated XP |
| **Persistent Storage** | All game state survives session restarts via the SQLite `.db` file |

---

## 🛠 Technologies Used

| Technology | Purpose |
|---|---|
| **Godot Engine 4.x** | 3D game engine — scene management, rendering, physics, animation, input handling |
| **GDScript** | Native scripting for gameplay logic, UI, database calls, and 3D interactions |
| **SQLite (godot-sqlite plugin)** | Embedded relational database — full SQL with no server required |
| **DB Browser for SQLite** | GUI tool for schema design, query testing, and data inspection during development |
| **Git & GitHub** | Version control, collaboration, and project showcase |

### Why Godot for a 3D Game?

Godot's node tree makes 3D scene composition natural — the shop environment, 3D customer characters, workstations, and UI overlays are all isolated scenes that communicate through signals. Godot's built-in 3D physics handles customer movement and interaction zones without any third-party engine dependency.

---

## 🗄 Database Integration

### Why SQLite?

| Criteria | Why It Fits |
|---|---|
| **Serverless** | The entire database is one `.db` file — ships with the game, no setup required |
| **Zero Configuration** | No server, no connection strings, no network ports |
| **Full SQL Support** | Supports DDL, DML, joins, subqueries, triggers, views, and transactions |
| **Persistent Storage** | Survives game restarts — orders, inventory, and player progress are never lost |
| **Lightweight** | Minimal memory footprint — ideal alongside a 3D rendering workload |
| **Portable** | The `.db` file runs identically on Windows, Linux, and macOS |

### Connecting SQLite to Godot

The **[godot-sqlite](https://github.com/2shady4u/godot-sqlite)** GDExtension plugin wraps the native SQLite3 C library and exposes it as a first-class GDScript class.

**Setup:**
1. Install via Godot Asset Library → search `godot-sqlite`
2. Enable under `Project → Project Settings → Plugins`
3. Store the database at `res://silai_simulator` — the path used in `database.gd`

**`database.gd` — Connection & Initialization:**

```gdscript
extends Node

const DB_PATH := "res://silai_simulator"
var db: SQLite = null

func _ready() -> void:
    _open_db()
    _create_tables()
    _drop_triggers()
    _create_triggers()
    _drop_views()
    _create_views()
    _prefill_data()
    print("═══ Database: Fully initialized. ═══")
```

### Executing Queries from GDScript

All SQL lives in `database.gd`, registered as an **Autoload Singleton** (`Database`). Any script calls `Database.function_name()` — no instantiation, no duplicated SQL anywhere in the project.

```gdscript
# All queries follow this pattern in database.gd
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
    return db.query_result.duplicate()   # Array[Dictionary] — column name → value
```

---

## 📚 DBMS Concepts Applied

---

### 1. Data Definition Language (DDL)

**Theory:** DDL statements (`CREATE TABLE`, `ALTER TABLE`, `DROP TABLE`) define database structure — tables, columns, data types, primary keys, foreign keys, and constraints. DDL shapes the schema before any data can be stored.

**In This Project:**

The full schema is initialized on first launch via `_create_tables()` in `database.gd`, using `CREATE TABLE IF NOT EXISTS` so the game is entirely self-initializing — no manual database setup is ever needed.

```gdscript
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
```

**Gameplay Relevance:** Adding a new fabric, dress type, or machine never requires a code change — only a new row in the appropriate table.

---

### 2. Derived Attribute — `Total_Price`

**Theory:** A derived attribute's value is **not stored** in the database — it is **computed on demand** from other stored data. Physically storing a derived value creates update anomalies: if the base data changes, the stored copy becomes stale and incorrect.

**In This Project:**

`Total_Price` represents the total cost of an order. Rather than storing this number, it is calculated at query time by summing `Unit_cost × Quantity_used` across every part in every dress belonging to the order, then applying the customer's VIP discount if applicable.

```sql
-- Total_price is derived: sum of (unit_cost × quantity_used) per part, with VIP discount
SELECT ROUND(
    COALESCE(SUM(f.Unit_cost * dp.Quantity_used), 0.0)
    * (1.0 - COALESCE(
        (SELECT v.Discount_rate / 100.0
         FROM   VIP      v
         JOIN   "Order"  o_v ON o_v.CustomerID = v.CustomerID
         WHERE  o_v.OrderID = 18),
        0.0
    )),
    2
) AS Total_price
FROM  Dress       d
JOIN  Dress_Parts dp ON dp.DressID  = d.DressID
JOIN  Fabric       f ON  f.FabricID = dp.FabricID
WHERE d.OrderID = 18;
```

In `database.gd`:

```gdscript
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
```

**Example result for OrderID = 18 (two dresses, customer is VIP with 15% discount):**

| Component | Detail | Cost |
|---|---|---|
| Dress 1 — Front Panel | Cotton × 0.20 m | 10.00 |
| Dress 1 — Back Panel | Cotton × 0.20 m | 10.00 |
| Dress 1 — Sleeve | Silk × 0.15 m | 22.50 |
| Dress 1 — Collar | Lawn × 0.45 m | 27.00 |
| Dress 2 — Bodice | Linen × 0.15 m | 12.00 |
| Dress 2 — Skirt | Chiffon × 1.60 m | 192.00 |
| **Subtotal** | | **273.50** |
| **VIP Discount (15%)** | | **−41.03** |
| **Total_price** | | **232.47** |

**Why not store it?** If a part's `Quantity_used` changes, or fabric `Unit_cost` is updated, or the customer's VIP discount rate is modified, any stored `Total_price` would require a manual update — risking inconsistency. Deriving it at query time guarantees it is always accurate.

---

### 3. Data Manipulation Language (DML)

**Theory:** DML covers `SELECT`, `INSERT`, `UPDATE`, and `DELETE` — the four operations for reading and modifying table data. Every gameplay event in Silai Simulator maps to one or more DML statements.

**In This Project (`database.gd`):**

```gdscript
# ── INSERT: New customer walks into the 3D shop ──────────────────────────────
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

    # Insert VIP or Rude specialization rows based on name lists
    var name: String = data["Name"]
    if name in VIP_NAMES:
        var discount: float = float(randi_range(VIP_DISCOUNT_RANGE[0], VIP_DISCOUNT_RANGE[1]))
        db.query_with_bindings(
            "INSERT OR IGNORE INTO VIP (CustomerID, Discount_rate) VALUES (?, ?);",
            [active_customer_id, discount]
        )
    elif name in RUDE_NAMES:
        var delay: int = randi_range(RUDE_DELAY_RANGE[0], RUDE_DELAY_RANGE[1])
        db.query_with_bindings(
            "INSERT OR IGNORE INTO Rude (CustomerID, Time_delay) VALUES (?, ?);",
            [active_customer_id, delay]
        )

# ── INSERT: Order placed at the counter ──────────────────────────────────────
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
    return active_order_id

# ── INSERT: per-part Dress_Parts (trigger fires on each insert) ──────────────
db.query_with_bindings("""
    INSERT OR IGNORE INTO Dress_Parts (DressID, Part_name, FabricID, Quantity_used)
    VALUES (?, ?, ?, ?);
""", [active_dress_id, part.get("part_name", "Part"), fabric_id, float(part.get("quantity", 1.0))])
# trg_deduct_fabric_stock fires automatically per INSERT above

# ── SELECT: Load all pending orders for the order board ──────────────────────
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

# ── UPDATE: Mark order completed after sewing is done ────────────────────────
func finalize_order(order_id: int) -> void:
    db.query_with_bindings(
        "UPDATE \"Order\" SET Order_status = 'Completed' WHERE OrderID = ?;",
        [order_id]
    )
    var price: float = calculate_order_price(order_id)
    print("Database: Order %d finalized → Completed. Calculated price = %.2f coins." % [order_id, price])

# ── UPDATE: Mark a completed order as Delivered and Paid ─────────────────────
func deliver_order(order_id: int) -> void:
    db.query_with_bindings("""
        UPDATE "Order"
        SET    Order_status   = 'Delivered',
               Payment_status = 'Paid'
        WHERE  OrderID      = ?
          AND  Order_status = 'Completed';
    """, [order_id])

# ── UPDATE: Reward player with coins and XP ───────────────────────────────────
func add_player_rewards(xp: int, coins: int) -> void:
    db.query_with_bindings("""
        UPDATE Player
        SET Current_xp = Current_xp + ?,
            Coins      = Coins      + ?
        WHERE PlayerID = 1;
    """, [xp, coins])
    # trg_player_level_up fires automatically and recalculates Level
```

---

### 4. Entity Relationship Modeling (ERM / EERM)

**Theory:** ERM identifies entities, their attributes, and relationships between them. Extended ERM adds specialization/generalization (ISA hierarchies), weak entities, and multivalued attributes.

**In This Project (Phase 3 Mapping):**

```
REGULAR ENTITIES
────────────────────────────────────────────────────────────────
Customer    → CustomerID (PK), Name, House, Street, Sector, City,
              Collar_size, Chest, Shoulder, Sleeve_length, Trouser_length, Waist

Order       → OrderID (PK), CustomerID (FK), Order_date, Receiving_date,
              Payment_status, Order_status
              ↳ Total_price — DERIVED via SUM(Unit_cost × Quantity_used) with VIP discount

Dress       → DressID (PK), OrderID (FK), Dress_type

Fabric      → FabricID (PK), Fabric_type, Unit_cost, Stock_quantity

ShopItems   → ItemID (PK), Item_name, Price, Unlock_Status, Use_Status

Player      → PlayerID (PK), Username, Level, Coins, Current_xp

MULTIVALUED ATTRIBUTES (extracted to separate tables)
──────────────────────────────────────────────────────
Customer_Phone  → (CustomerID FK, PhoneNo)
Dress_Color     → (DressID FK, Color)

SPECIALIZATION / ISA HIERARCHIES
─────────────────────────────────
Customer  ──ISA──> VIP   (CustomerID PK/FK, Discount_rate)
Customer  ──ISA──> Rude  (CustomerID PK/FK, Time_delay)
ShopItems ──ISA──> Machine (ItemID PK/FK, Type, Speed)

M:N RELATIONSHIP RESOLVED
──────────────────────────
Dress_Parts bridges Dress ↔ Fabric
(a dress has many named parts; each part references exactly one fabric and
 stores Quantity_used in metres, computed from the customer's measurements)
```

---

### 5. Normalization

**Theory:** Normalization organizes tables to eliminate redundancy and prevent anomalies by ensuring non-key attributes satisfy progressively strict rules across Normal Forms (1NF → 2NF → 3NF → BCNF).

**Applied to Silai Simulator:**

| Normal Form | Violation (Before Normalization) | Resolution Applied |
|---|---|---|
| **1NF** | `PhoneNo` stored as a comma-separated list in `Customer` | Extracted to `Customer_Phone(CustomerID, PhoneNo)` |
| **1NF** | `Color` stored as a multi-value string in `Dress` | Extracted to `Dress_Color(DressID, Color)` |
| **2NF** | `Fabric_type` and `Unit_cost` stored inside a Dress-Fabric join table (depended only on `FabricID`, not the full composite key) | Moved to standalone `Fabric` table; join stores only the FK |
| **3NF** | `Total_price` in `Order` — transitively derivable from `Dress_Parts.Quantity_used × Fabric.Unit_cost` | Made a **derived attribute** — computed via `SUM()` at query time; not stored |
| **BCNF** | `Dress_Parts` + `Dress_Fabric` were initially two separate tables that partially overlapped | Merged into a single `Dress_Parts(DressID, Part_name, FabricID, Quantity_used)` as documented in Phase 3 |

**Result:** Every non-key attribute in the final schema depends on the **whole** primary key and **nothing but** the primary key — satisfying 3NF throughout.

---

### 6. Functional Dependencies & Database Anomalies

**Theory:** A Functional Dependency `A → B` means knowing `A` uniquely determines `B`. Anomalies — Insertion, Update, and Deletion — arise from poor structure where data is redundant or entangled.

**Key Functional Dependencies in the Schema:**

```
CustomerID               → Name, House, Street, Sector, City, Collar_size,
                           Chest, Shoulder, Sleeve_length, Trouser_length, Waist
OrderID                  → CustomerID, Order_date, Receiving_date,
                           Payment_status, Order_status
                           [Total_price is DERIVED, not stored]
DressID                  → OrderID, Dress_type
FabricID                 → Fabric_type, Unit_cost, Stock_quantity
ItemID                   → Item_name, Price, Unlock_Status, Use_Status
PlayerID                 → Username, Level, Coins, Current_xp
(DressID, Part_name,
 FabricID)               → Quantity_used    [composite PK in Dress_Parts]
(CustomerID, PhoneNo)    → (identifier only, no extra attributes)
```

**Anomalies Eliminated by the Schema:**

| Anomaly | Scenario | How It's Prevented |
|---|---|---|
| **Insertion** | Couldn't record a fabric until it was assigned to a dress part | `Fabric` is a standalone table — fabrics exist independently of orders |
| **Update** | Changing a fabric's `Unit_cost` required updating every dress row that referenced it | `Unit_cost` lives only in `Fabric` — one row update propagates everywhere automatically |
| **Deletion** | Deleting all dress parts for a fabric would destroy the fabric's existence record | `Fabric` exists independently — `Dress_Parts` rows CASCADE-delete but `Fabric` rows remain |

---

### 7. Joins

**Theory:** Joins combine rows from multiple tables using a matching column. `INNER JOIN` returns only matching rows on both sides; `LEFT JOIN` includes all rows from the left table even with no match on the right.

**In This Project (`database.gd`):**

```gdscript
# LEFT JOIN: Full dress breakdown for a given order (colors + fabrics per dress)
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

# JOIN with ISA: Order summary including VIP discount and Rude delay
func get_order_details(order_id: int) -> Dictionary:
    db.query_with_bindings("SELECT * FROM v_order_summary WHERE OrderID = ?;", [order_id])
    if db.query_result.is_empty(): return {}
    return db.query_result[0].duplicate()

# JOIN: Full dress cost breakdown with per-part fabric costs
func get_dress_cost_breakdown(dress_id: int) -> Array:
    db.query_with_bindings("SELECT * FROM v_dress_cost_breakdown WHERE DressID = ?;", [dress_id])
    return db.query_result.duplicate()

# JOIN: Top delivery areas — completed but undelivered orders, revenue derived from parts
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
```

---

### 8. Subqueries

**Theory:** A subquery is a `SELECT` statement nested inside another SQL statement. They appear in `WHERE`, `FROM`, or `SELECT` clauses. A correlated subquery references the outer query's current row.

**In This Project (`database.gd`):**

```gdscript
# Correlated subquery in SELECT: VIP discount applied per order
# (used inside calculate_order_price and all three views)
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

# Correlated subquery in SELECT: per-customer discount in v_customer_spending
ROUND(COALESCE(SUM(
    f.Unit_cost * dp.Quantity_used *
    (1.0 - COALESCE(
        (SELECT v2.Discount_rate / 100.0 FROM VIP v2
         WHERE v2.CustomerID = c.CustomerID),
        0.0
    ))
), 0.0), 2) AS Total_spent

# Subquery in WHERE: Deliver all completed orders in a given city area
func deliver_orders_for_area(city: String) -> Dictionary:
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

# Subquery in SELECT: Revenue aggregated before marking as delivered
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
```

---

### 9. Triggers

**Theory:** A trigger is a stored SQL procedure that fires automatically on `INSERT`, `UPDATE`, or `DELETE` events. Triggers enforce business rules at the database level, independent of application code — guaranteeing consistency even if GDScript logic has a bug.

**In This Project (`database.gd`):**

```gdscript
func _create_triggers() -> void:

    # TRIGGER: Auto-calculate player level whenever XP changes
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

    # TRIGGER: Deduct fabric stock when a dress part is inserted
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
```

**Gameplay Relevance:**
- `trg_player_level_up` — every `add_player_rewards()` call automatically recalculates the player's level from their accumulated XP; the HUD always reflects the correct value without any extra GDScript logic.
- `trg_deduct_fabric_stock` — every time a dress part is inserted into `Dress_Parts`, the corresponding fabric's stock is reduced by the exact `Quantity_used`. Stock accuracy is guaranteed at the database level even if application code has a bug.

---

### 10. Views

**Theory:** A `VIEW` is a saved SQL query that behaves as a virtual table. Views simplify complex queries, hide schema details from application scripts, and present data pre-shaped for a specific use case.

**In This Project (`database.gd`):**

```gdscript
func _create_views() -> void:

    # VIEW: Full order summary — customer type, colors, derived price with VIP discount
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

    # VIEW: Per-part cost breakdown for every dress
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

    # VIEW: Customer spending summary — total and average order value (completed/delivered only)
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
```

**Querying views in GDScript — identical to querying a table:**

```gdscript
func get_order_details(order_id: int) -> Dictionary:
    db.query_with_bindings("SELECT * FROM v_order_summary WHERE OrderID = ?;", [order_id])
    if db.query_result.is_empty(): return {}
    return db.query_result[0].duplicate()

func get_dress_cost_breakdown(dress_id: int) -> Array:
    db.query_with_bindings("SELECT * FROM v_dress_cost_breakdown WHERE DressID = ?;", [dress_id])
    return db.query_result.duplicate()

func get_top_customers(limit: int = 5) -> Array:
    db.query_with_bindings(
        "SELECT * FROM v_customer_spending ORDER BY Total_spent DESC LIMIT ?;",
        [limit]
    )
    return db.query_result.duplicate()
```

---

## 🗃 Database Schema & Relationships

### Final Relational Schema (Phase 3 Output)

```
Customer(CustomerID PK, Name UNIQUE, House, Street, Sector, City,
         Collar_size, Chest, Shoulder, Sleeve_length, Trouser_length, Waist)

Customer_Phone(CustomerID FK→Customer, PhoneNo)              -- multivalued attr

VIP(CustomerID PK/FK→Customer, Discount_rate)               -- ISA specialization
Rude(CustomerID PK/FK→Customer, Time_delay)                 -- ISA specialization

Order(OrderID PK, CustomerID FK→Customer, Order_date,
      Receiving_date, Payment_status, Order_status)
      ↳ Total_price : DERIVED — SUM(Unit_cost × Quantity_used) × (1 − Discount_rate)

Dress(DressID PK, OrderID FK→Order, Dress_type)

Dress_Color(DressID FK→Dress, Color)                        -- multivalued attr

Dress_Parts(DressID PK/FK→Dress, Part_name PK,              -- M:N bridge
            FabricID PK/FK→Fabric, Quantity_used REAL)
            ↳ Quantity_used stored in metres, derived per customer measurements

Fabric(FabricID PK, Fabric_type UNIQUE, Unit_cost, Stock_quantity)

ShopItems(ItemID PK, Item_name UNIQUE, Price, Unlock_Status, Use_Status)

Machine(ItemID PK/FK→ShopItems, Type, Speed)                -- ISA specialization

Player(PlayerID PK, Username UNIQUE, Level, Coins, Current_xp)
```

### Entity Relationship Map

```
Customer ──────────────────────────< Order >────────────── Dress
   │                                                          │
   ├──< Customer_Phone (multivalued)              Dress_Color │ (multivalued)
   │                                                          │
   ├── VIP   (ISA)                                 Dress_Parts ──────> Fabric
   └── Rude  (ISA)                                     ↑
                                               Quantity_used
ShopItems                                      (stored, computed from measurements)
   └── Machine (ISA)

Player (standalone — tracks progression; Level derived via trigger from Current_xp)
```

### Constraint Summary

| Table | Primary Key | Foreign Keys | Special |
|---|---|---|---|
| `Customer` | `CustomerID` | — | Root entity |
| `Customer_Phone` | `(CustomerID, PhoneNo)` | `CustomerID → Customer` | Multivalued attr |
| `VIP` | `CustomerID` | `→ Customer` | ISA — one row per VIP |
| `Rude` | `CustomerID` | `→ Customer` | ISA — one row per Rude |
| `Order` | `OrderID` | `CustomerID → Customer` | Status: `Pending`/`Completed`/`Delivered` |
| `Dress` | `DressID` | `OrderID → Order` | CASCADE on delete |
| `Dress_Color` | `(DressID, Color)` | `DressID → Dress` | Multivalued attr |
| `Dress_Parts` | `(DressID, Part_name, FabricID)` | `DressID → Dress`, `FabricID → Fabric` | M:N bridge; stock deducted by trigger |
| `Fabric` | `FabricID` | — | Independent; stock managed by trigger |
| `ShopItems` | `ItemID` | — | Superclass |
| `Machine` | `ItemID` | `→ ShopItems` | ISA specialization |
| `Player` | `PlayerID` | — | Singleton game record; Level set by trigger |

---

## 🏗 Workflow Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                       GODOT ENGINE (3D)                           │
│                                                                   │
│   ┌──────────────────────┐  signals  ┌───────────────────────┐   │
│   │    3D Game Scenes    │ ─────────>│   GDScript Files      │   │
│   │                      │           │                       │   │
│   │  • ShopScene.tscn    │ <─────────│  • ShopScene.gd       │   │
│   │  • Customer3D.tscn   │  UI/scene │  • CustomerManager.gd │   │
│   │  • OrderBoard.tscn   │  updates  │  • OrderSystem.gd     │   │
│   │  • CuttingTable.tscn │           │  • InventorySystem.gd │   │
│   │  • SewingMachine.tscn│           │  • RewardSystem.gd    │   │
│   │  • HUD.tscn          │           │  • HUD.gd             │   │
│   └──────────────────────┘           └──────────┬────────────┘   │
│                                                  │                │
│                                        Database.*() calls         │
│                                                  │                │
│                                                  ▼                │
│                                   ┌──────────────────────────┐   │
│                                   │       database.gd         │   │
│                                   │  (Autoload Singleton)    │   │
│                                   │                          │   │
│                                   │  _open_db()              │   │
│                                   │  _create_tables()        │   │
│                                   │  _drop/create_triggers() │   │
│                                   │  _drop/create_views()    │   │
│                                   │  _prefill_data()         │   │
│                                   │  + all CRUD functions    │   │
│                                   └─────────────┬────────────┘   │
│                                                 │                 │
└─────────────────────────────────────────────────┼─────────────────┘
                                                  │ SQL via godot-sqlite
                                                  ▼
                                   ┌──────────────────────────┐
                                   │    silai_simulator.db    │
                                   │   (SQLite Database)      │
                                   │                          │
                                   │  Customer / VIP / Rude   │
                                   │  Customer_Phone          │
                                   │  Order                   │
                                   │  Dress / Dress_Color     │
                                   │  Dress_Parts             │
                                   │  Fabric                  │
                                   │  ShopItems / Machine     │
                                   │  Player                  │
                                   └──────────────────────────┘
```

### Design Principles

- **GUI scenes** contain nodes and layout only — no business logic, no SQL.
- **GDScript system files** handle gameplay events and call `Database.*` functions.
- **`database.gd`** is the single point of contact with SQLite — no other script writes SQL.
- **Triggers** enforce data integrity at the database level, independent of GDScript.
- **Views** pre-join tables so UI scripts receive clean, ready-to-use data arrays.

---

## 🔄 Functional Flow

### Complete Order Lifecycle — Step by Step

```
STEP 1 — CUSTOMER ARRIVES
═══════════════════════════
CustomerManager.gd spawns a 3D character, calls get_or_create_customer().

  Database.get_or_create_customer("Ayesha")
  → SELECT * FROM Customer WHERE Name = 'Ayesha'   (not found → create)
  → INSERT INTO Customer (Name, House, Street, Sector, City,
        Collar_size, Chest, Shoulder, Sleeve_length, Trouser_length, Waist)
        VALUES (...)
  → Returns: CustomerID = 7, customer_type = "VIP"

  Because "Ayesha" is in VIP_NAMES:
  → INSERT OR IGNORE INTO VIP (CustomerID, Discount_rate) VALUES (7, 18.0)

────────────────────────────────────────────────────────────────────
STEP 2 — ORDER PLACED AT THE COUNTER
═══════════════════════════════════════
generate_random_dress_order() builds the order dict; create_order_record() saves it.

  Database.create_order_record(7)
  → INSERT INTO "Order" (CustomerID, Order_date, Receiving_date,
        Payment_status, Order_status) VALUES (7, '2026-05-10T...', '2026-05-13', 'Unpaid', 'Pending')
  → Returns: OrderID = 42
    (Receiving_date = today + BASE_RECEIVING_DAYS; no delay for VIP)

  Database.attach_all_dresses_to_order(42, order_data)
  → INSERT INTO Dress (OrderID, Dress_type) VALUES (42, 'Frock')
    → DressID = 18
  → INSERT OR IGNORE INTO Dress_Color (DressID, Color) VALUES (18, 'Crimson Red')
  → INSERT OR IGNORE INTO Dress_Parts (DressID, Part_name, FabricID, Quantity_used)
        VALUES (18, 'Bodice', 3, 0.25), (18, 'Skirt', 6, 1.65), ...
    ★ trg_deduct_fabric_stock fires on each Dress_Parts INSERT:
      UPDATE Fabric SET Stock_quantity = Stock_quantity - <Quantity_used>
      WHERE FabricID = <FabricID>

────────────────────────────────────────────────────────────────────
STEP 3 — PRICE SHOWN TO PLAYER
════════════════════════════════
Called right after attach_all_dresses_to_order() to display price on the accept screen.

  Database.calculate_order_price(42)
  → SUM(Unit_cost × Quantity_used) × (1 − 0.18)   [VIP 18% discount]
  → Returns: 198.45

────────────────────────────────────────────────────────────────────
STEP 4 — PLAYER AT THE CUTTING TABLE / SEWING MACHINE
═══════════════════════════════════════════════════════
Player navigates to the 3D workstations. Pending order is loaded for display.

  Database.get_pending_orders()
  → Returns all orders WHERE Order_status = 'Pending'

  Database.get_dresses_for_order(42)
  → Returns dress rows with Colors and Fabrics for the order board

────────────────────────────────────────────────────────────────────
STEP 5 — ORDER COMPLETED
══════════════════════════
Player finishes sewing. finalize_order() advances status to Completed.

  Database.finalize_order(42)
  → UPDATE "Order" SET Order_status = 'Completed' WHERE OrderID = 42
  → calculate_order_price(42) called internally for the print log

────────────────────────────────────────────────────────────────────
STEP 6 — DELIVERY & REWARDS
══════════════════════════════
Player delivers at the counter. deliver_order() or deliver_orders_for_area() is called.

  Database.deliver_order(42)
  → UPDATE "Order" SET Order_status = 'Delivered', Payment_status = 'Paid'
    WHERE OrderID = 42 AND Order_status = 'Completed'

  Database.add_player_rewards(xp, coins)
  → UPDATE Player SET Current_xp = Current_xp + xp, Coins = Coins + coins
    WHERE PlayerID = 1
  ★ trg_player_level_up fires:
    UPDATE Player SET Level = MAX(1, (NEW.Current_xp / 500) + 1)
    WHERE PlayerID = NEW.PlayerID

────────────────────────────────────────────────────────────────────
STEP 7 — HUD UPDATES IN REAL TIME
════════════════════════════════════
HUD.gd queries player data each cycle:

  Database.get_player_data()
  → SELECT PlayerID, Username, Level, Coins, Current_xp,
           (Level * 500) - Current_xp AS xp_to_next_level
    FROM Player WHERE PlayerID = 1
  → { Level:3, Coins:850, Current_xp:1225, xp_to_next_level:275 }

  3D HUD overlay updates: level badge, coin counter, XP progress bar.

────────────────────────────────────────────────────────────────────
STEP 8 — SESSION ENDS
═══════════════════════
SQLite commits all changes to silai_simulator.db on disk.
Next launch: database.gd opens the same file.
Every customer, order, fabric level, and coin is exactly as left.
```

---

## 📁 File Structure

```
Silai-Simulator/
│
├── project.godot                      # Godot 4 project configuration
├── silai_simulator.db                 # SQLite database (auto-created on first launch)
│
├── addons/
│   └── godot-sqlite/                  # GDExtension SQLite plugin
│       ├── bin/                       # Native binaries (Win/Linux/macOS)
│       └── godot-sqlite.gdextension
│
├── autoloads/
│   └── database.gd                    # ★ Singleton — ALL SQL lives here
│                                      #   _open_db(), _create_tables(),
│                                      #   _drop/create_triggers(),
│                                      #   _drop/create_views(),
│                                      #   _prefill_data(),
│                                      #   + all public CRUD functions
│
├── scenes/
│   ├── shop/
│   │   ├── ShopScene.tscn             # Main 3D shop environment
│   │   └── ShopScene.gd              # Core loop — spawn, order flow
│   ├── customer/
│   │   ├── Customer3D.tscn           # Animated 3D customer character
│   │   └── CustomerManager.gd        # Customer generation + DB insert
│   ├── workstations/
│   │   ├── CuttingTable.tscn         # 3D cutting table
│   │   ├── CuttingTable.gd           # Dress_Parts insert, fabric deduction
│   │   ├── SewingMachine.tscn        # 3D sewing machine
│   │   └── SewingMachine.gd          # Machine unlock check, order progress
│   ├── ui/
│   │   ├── OrderBoard.tscn           # 3D in-world order board
│   │   ├── OrderBoard.gd             # Queries get_pending_orders()
│   │   ├── HUD.tscn                  # Coins, XP, Level overlay
│   │   └── HUD.gd                    # Queries get_player_data()
│   └── main_menu/
│       ├── MainMenu.tscn
│       └── MainMenu.gd
│
├── scripts/
│   ├── OrderSystem.gd                # Order + Dress creation, status transitions
│   ├── InventorySystem.gd            # Fabric stock queries, low-stock alerts
│   ├── RewardSystem.gd               # Coin/XP calculation, player update calls
│   └── LevelSystem.gd                # Level-up detection, ShopItems unlock
│
└── assets/
    ├── models/                       # 3D shop and character models (.glb)
    ├── textures/                     # Material textures
    ├── animations/                   # Customer walk/idle animations
    └── fonts/
```

---

## ⚙ Advanced Query System

### Aggregate Functions

```gdscript
# Total earnings from all completed and delivered orders (derived from parts)
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

# Top 5 customers by total amount spent
func get_top_customers(limit: int = 5) -> Array:
    db.query_with_bindings(
        "SELECT * FROM v_customer_spending ORDER BY Total_spent DESC LIMIT ?;",
        [limit]
    )
    return db.query_result.duplicate()

# Top delivery areas: cities with most completed-but-undelivered orders
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

# Player stats including XP needed to reach the next level
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
```

### Fabric Stock Management

```gdscript
# Fabric stock is reduced automatically by trg_deduct_fabric_stock.
# VIP discount is fetched inline when needed:
func get_vip_discount(customer_id: int) -> float:
    db.query_with_bindings(
        "SELECT Discount_rate FROM VIP WHERE CustomerID = ?;",
        [customer_id]
    )
    if db.query_result.is_empty(): return 0.0
    return float(db.query_result[0]["Discount_rate"])

# Rude customer delay added to BASE_RECEIVING_DAYS when computing Receiving_date:
func get_rude_delay(customer_id: int) -> int:
    db.query_with_bindings(
        "SELECT Time_delay FROM Rude WHERE CustomerID = ?;",
        [customer_id]
    )
    if db.query_result.is_empty(): return 0
    return int(db.query_result[0]["Time_delay"])
```

---

## 🧩 Software Engineering Concepts

### Modular Programming

Each game system is a self-contained script with a single clear responsibility:

| Script | Does | Does Not |
|---|---|---|
| `database.gd` | All SQL: schema, triggers, views, CRUD | No scene logic, no game math |
| `OrderSystem.gd` | Order state machine transitions | No SQL, no rendering |
| `RewardSystem.gd` | Calculates coin/XP values | No DB calls, no UI updates |
| `HUD.gd` | Reads `get_player_data()`, updates labels | No business logic |
| `CuttingTable.gd` | Inserts `Dress_Parts` rows | No view rendering |

### Separation of Frontend and Backend

```
FRONTEND (Scenes + UI Scripts)           BACKEND (System Scripts + database.gd)
──────────────────────────────           ──────────────────────────────────────
Render the 3D shop environment           Manage order lifecycle state machine
Animate 3D customer characters           Generate customer data and measurements
Display order cards and urgency flags    Execute all database queries
Handle player movement and input         Calculate rewards, apply VIP discounts
Show fabric stock levels visually        Enforce stock accuracy via triggers
Update XP bar and level badge            Maintain schema, views, triggers
```

No frontend script contains SQL. No backend script touches scene nodes. All communication flows through function return values and Godot signals.

### Scalability Considerations

| Future Requirement | How the Architecture Handles It |
|---|---|
| Add a new dress type | Add a new `match` branch in `get_dress_parts()` — no schema change needed |
| Add a new fabric | `INSERT` into `Fabric` — triggers and views adapt automatically |
| New customer subclass (e.g. Loyal) | New ISA table with FK to `Customer` — existing queries unaffected |
| Multiple save slots | Add `SaveSlot INTEGER` to `Player`, filter all queries by slot |
| Leaderboard / multiplayer | `Player.Username UNIQUE` already exists — extend with a sync layer |
| New machine category | Add to `ShopItems` + `Machine` — unlock system inherits it immediately |

---

## 👥 Group Members

| Name | Roll No |
|---|---|
| Abdul Rehman Riaz | 542715 |
| Muhammad Uzair Khan | 545846 |
| Muhammad Musa Toor | 552718 |
| Hashim Abdullah | 551504 |

**Section:** BSCS-15-E &nbsp;|&nbsp; **Course:** CS-220 Database Systems &nbsp;|&nbsp; **Semester:** Spring 2026

---

<div align="center">

*Every stitch is a transaction. Every order is a query. Every delivery is a commit.*

</div>