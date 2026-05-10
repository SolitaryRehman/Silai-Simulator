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
| **Order Management** | Each order tracks dress type, assigned fabrics, order/receiving dates, payment status, and completion status |
| **Dress & Parts System** | Each dress is composed of named parts (e.g. collar, body, sleeves); each part references a fabric. `Quantity_used` is a **derived attribute** |
| **VIP & Rude Customers** | Customer specialization — VIP customers get automatic discounts; Rude customers impose time penalties |
| **Inventory System** | Fabrics tracked with type, unit cost, and stock quantity; stock depletes as parts are cut |
| **Reward & Progression** | Orders earn Coins and XP; leveling up unlocks new ShopItems and Machines |
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
3. Store the database at `user://` — Godot's writable app-data directory

**`database.gd` — Connection & Initialization:**

```gdscript
extends Node

const PATH = "user://silai.db"
var db : SQLite = SQLite.new()

func _ready() -> void:
    db.path = PATH
    db.open_db()
    _create_tables()
    _create_triggers()
    _create_views()
    _create_indexes()
```

> **Why `user://`?** The `res://` directory is read-only in exported builds. `user://` maps to the OS app-data folder, giving the database full read/write access on every platform including Android.

### Executing Queries from GDScript

All SQL lives in `database.gd`, registered as an **Autoload Singleton** (`Database`). Any script calls `Database.function_name()` — no instantiation, no duplicated SQL anywhere in the project.

```gdscript
# All queries follow this pattern in database.gd
func get_pending_orders() -> Array:
    db.query("""
        SELECT o.OrderID, c.Name, o.Receiving_date, o.Total_price
        FROM "Order" o
        JOIN Customer c ON o.CustomerID = c.CustomerID
        WHERE o.Order_status = 'Pending'
        ORDER BY o.Receiving_date ASC;
    """)
    return db.query_result   # Array[Dictionary] — column name → value
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
            Name            TEXT    NOT NULL,
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
            FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS VIP (
            CustomerID    INTEGER PRIMARY KEY,
            Discount_rate REAL    NOT NULL,
            FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS Rude (
            CustomerID  INTEGER PRIMARY KEY,
            Time_delay  INTEGER NOT NULL,
            FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID) ON DELETE CASCADE
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS "Order" (
            OrderID         INTEGER PRIMARY KEY AUTOINCREMENT,
            CustomerID      INTEGER NOT NULL,
            Order_date      TEXT    NOT NULL DEFAULT (DATE('now')),
            Receiving_date  TEXT    NOT NULL,
            Payment_status  TEXT    NOT NULL DEFAULT 'Unpaid'
                            CHECK(Payment_status IN ('Paid','Unpaid')),
            Order_status    TEXT    NOT NULL DEFAULT 'Pending'
                            CHECK(Order_status IN ('Pending','In Progress','Completed','Failed')),
            Total_price     REAL    NOT NULL DEFAULT 0,
            FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID)
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS Dress (
            DressID     INTEGER PRIMARY KEY AUTOINCREMENT,
            OrderID     INTEGER NOT NULL,
            Dress_type  TEXT    NOT NULL,
            FOREIGN KEY (OrderID) REFERENCES "Order"(OrderID) ON DELETE CASCADE
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS Dress_Color (
            DressID INTEGER NOT NULL,
            Color   TEXT    NOT NULL,
            PRIMARY KEY (DressID, Color),
            FOREIGN KEY (DressID) REFERENCES Dress(DressID) ON DELETE CASCADE
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS Fabric (
            FabricID       INTEGER PRIMARY KEY AUTOINCREMENT,
            Fabric_type    TEXT    NOT NULL,
            Unit_cost      REAL    NOT NULL,
            Stock_quantity INTEGER NOT NULL DEFAULT 0
        );
    """)

    # Dress_Parts: weak entity + resolved M:N bridge (Dress ↔ Fabric)
    # NOTE: Quantity_used is a DERIVED attribute — it is NOT stored here.
    #       It is computed at query time via COUNT(Part_name) GROUP BY FabricID.
    db.query("""
        CREATE TABLE IF NOT EXISTS Dress_Parts (
            DressID   INTEGER NOT NULL,
            Part_name TEXT    NOT NULL,
            FabricID  INTEGER NOT NULL,
            PRIMARY KEY (DressID, Part_name),
            FOREIGN KEY (DressID)  REFERENCES Dress(DressID)   ON DELETE CASCADE,
            FOREIGN KEY (FabricID) REFERENCES Fabric(FabricID)
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS ShopItems (
            ItemID        INTEGER PRIMARY KEY AUTOINCREMENT,
            Item_name     TEXT    NOT NULL,
            Price         REAL    NOT NULL,
            Unlock_Status TEXT    NOT NULL DEFAULT 'Locked'
                          CHECK(Unlock_Status IN ('Locked','Unlocked')),
            Use_Status    TEXT    NOT NULL DEFAULT 'Inactive'
                          CHECK(Use_Status IN ('Active','Inactive'))
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS Machine (
            ItemID  INTEGER PRIMARY KEY,
            Type    TEXT    NOT NULL,
            Speed   REAL    NOT NULL,
            FOREIGN KEY (ItemID) REFERENCES ShopItems(ItemID) ON DELETE CASCADE
        );
    """)

    db.query("""
        CREATE TABLE IF NOT EXISTS Player (
            PlayerID    INTEGER PRIMARY KEY AUTOINCREMENT,
            Username    TEXT    NOT NULL UNIQUE,
            Level       INTEGER NOT NULL DEFAULT 1,
            Coins       REAL    NOT NULL DEFAULT 0,
            Current_xp  INTEGER NOT NULL DEFAULT 0
        );
    """)
```

**Gameplay Relevance:** Adding a new fabric, dress type, or machine never requires a code change — only a new row in the appropriate table.

---

### 2. Derived Attribute — `Quantity_used`

**Theory:** A derived attribute's value is **not stored** in the database — it is **computed on demand** from other stored data. Physically storing a derived value creates update anomalies: if the base data changes, the stored copy becomes stale and incorrect.

**In This Project:**

`Quantity_used` represents how many parts of a dress use a given fabric. Rather than storing this number, it is calculated at query time by counting the `Part_name` rows in `Dress_Parts` that share the same `FabricID` for a given dress.

```sql
-- Quantity_used is derived: count of parts per fabric per dress
SELECT
    dp.FabricID,
    f.Fabric_type,
    COUNT(dp.Part_name)                AS Quantity_used,
    COUNT(dp.Part_name) * f.Unit_cost  AS Fabric_cost
FROM Dress_Parts dp
JOIN Fabric f ON dp.FabricID = f.FabricID
WHERE dp.DressID = 18
GROUP BY dp.DressID, dp.FabricID;
```

In `database.gd`:

```gdscript
func get_fabric_usage_for_dress(dress_id: int) -> Array:
    db.query("""
        SELECT
            dp.FabricID,
            f.Fabric_type,
            f.Unit_cost,
            COUNT(dp.Part_name)               AS Quantity_used,
            COUNT(dp.Part_name) * f.Unit_cost AS Fabric_cost
        FROM Dress_Parts dp
        JOIN Fabric f ON dp.FabricID = f.FabricID
        WHERE dp.DressID = %d
        GROUP BY dp.FabricID;
    """ % dress_id)
    return db.query_result
```

**Example result for DressID = 18 (Shalwar Kameez using Cotton for body+collar, Silk for sleeves):**

| FabricID | Fabric_type | Unit_cost | Quantity_used | Fabric_cost |
|---|---|---|---|---|
| 3 | Cotton | 120.00 | 2 | 240.00 |
| 5 | Silk | 200.00 | 1 | 200.00 |

**Why not store it?** If a part is added or removed from `Dress_Parts`, any stored `Quantity_used` would require a manual update — risking inconsistency. Deriving it at query time guarantees it is always accurate.

---

### 3. Data Manipulation Language (DML)

**Theory:** DML covers `SELECT`, `INSERT`, `UPDATE`, and `DELETE` — the four operations for reading and modifying table data. Every gameplay event in Silai Simulator maps to one or more DML statements.

**In This Project (`database.gd`):**

```gdscript
# ── INSERT: New customer walks into the 3D shop ──────────────────────────────
func add_customer(name: String, city: String, chest: float, waist: float,
                  collar: float, shoulder: float, sleeve: float, trouser: float) -> int:
    db.query("""
        INSERT INTO Customer (Name, City, Chest, Waist, Collar_size, Shoulder, Sleeve_length, Trouser_length)
        VALUES ('%s', '%s', %f, %f, %f, %f, %f, %f);
    """ % [name, city, chest, waist, collar, shoulder, sleeve, trouser])
    return db.last_insert_rowid

# ── INSERT: Order placed at the counter ──────────────────────────────────────
func create_order(customer_id: int, receiving_date: String, total_price: float) -> int:
    db.query("""
        INSERT INTO "Order" (CustomerID, Receiving_date, Total_price)
        VALUES (%d, '%s', %f);
    """ % [customer_id, receiving_date, total_price])
    return db.last_insert_rowid

# ── INSERT: Dress part cut at the cutting table ───────────────────────────────
func add_dress_part(dress_id: int, part_name: String, fabric_id: int) -> void:
    db.query("""
        INSERT INTO Dress_Parts (DressID, Part_name, FabricID)
        VALUES (%d, '%s', %d);
    """ % [dress_id, part_name, fabric_id])

# ── SELECT: Load all pending orders for the order board ──────────────────────
func get_pending_orders() -> Array:
    db.query("""
        SELECT o.OrderID, c.Name, o.Receiving_date, o.Total_price, o.Order_status
        FROM "Order" o
        JOIN Customer c ON o.CustomerID = c.CustomerID
        WHERE o.Order_status = 'Pending'
        ORDER BY o.Receiving_date ASC;
    """)
    return db.query_result

# ── UPDATE: Mark order completed on delivery ──────────────────────────────────
func complete_order(order_id: int) -> void:
    db.query("""
        UPDATE "Order"
        SET Order_status   = 'Completed',
            Payment_status = 'Paid'
        WHERE OrderID = %d;
    """ % order_id)

# ── UPDATE: Reward player with coins and XP ───────────────────────────────────
func reward_player(player_id: int, coins: float, xp: int) -> void:
    db.query("""
        UPDATE Player
        SET Coins      = Coins      + %f,
            Current_xp = Current_xp + %d,
            Level      = (Current_xp + %d) / 500 + 1
        WHERE PlayerID = %d;
    """ % [coins, xp, xp, player_id])

# ── DELETE: Purge old failed orders ───────────────────────────────────────────
func purge_failed_orders() -> void:
    db.query("""
        DELETE FROM "Order"
        WHERE Order_status = 'Failed'
          AND Order_date < DATE('now', '-30 days');
    """)
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
              Payment_status, Order_status, Total_price

Dress       → DressID (PK), OrderID (FK), Dress_type

Fabric      → FabricID (PK), Fabric_type, Unit_cost, Stock_quantity

ShopItems   → ItemID (PK), Item_name, Price, Unlock_Status, Use_Status

Player      → PlayerID (PK), Username, Level, Coins, Current_xp

WEAK ENTITY (existence depends on Dress)
────────────────────────────────────────
Dress_Parts → (DressID PK/FK, Part_name PK), FabricID (FK)
              ↳ Quantity_used — DERIVED via COUNT(Part_name) GROUP BY FabricID

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
(a dress has many named parts; each part uses exactly one fabric;
 the same fabric can appear in many dress parts across many dresses)
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
| **3NF** | `Quantity_used` stored in `Dress_Parts` — it is transitively derivable from counting Part_name rows per FabricID | Made a **derived attribute** — computed via `COUNT()` at query time; not stored |
| **BCNF** | `Dress_Parts` + `Dress_Fabric` were initially two separate tables that partially overlapped | Merged into a single `Dress_Parts(DressID, Part_name, FabricID)` as documented in Phase 3 |

**Result:** Every non-key attribute in the final schema depends on the **whole** primary key and **nothing but** the primary key — satisfying 3NF throughout.

---

### 6. Functional Dependencies & Database Anomalies

**Theory:** A Functional Dependency `A → B` means knowing `A` uniquely determines `B`. Anomalies — Insertion, Update, and Deletion — arise from poor structure where data is redundant or entangled.

**Key Functional Dependencies in the Schema:**

```
CustomerID               → Name, House, Street, Sector, City, Collar_size,
                           Chest, Shoulder, Sleeve_length, Trouser_length, Waist
OrderID                  → CustomerID, Order_date, Receiving_date,
                           Payment_status, Order_status, Total_price
DressID                  → OrderID, Dress_type
FabricID                 → Fabric_type, Unit_cost, Stock_quantity
ItemID                   → Item_name, Price, Unlock_Status, Use_Status
PlayerID                 → Username, Level, Coins, Current_xp
(DressID, Part_name)     → FabricID       [composite PK in Dress_Parts]
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
# INNER JOIN: Full order board — orders, customer names, dress type, colors
func get_full_order_details() -> Array:
    db.query("""
        SELECT
            o.OrderID,
            c.Name            AS Customer_Name,
            c.City,
            d.Dress_type,
            GROUP_CONCAT(DISTINCT dc.Color) AS Colors,
            o.Order_date,
            o.Receiving_date,
            o.Total_price,
            o.Order_status,
            o.Payment_status
        FROM "Order" o
        INNER JOIN Customer    c  ON o.CustomerID = c.CustomerID
        INNER JOIN Dress        d  ON d.OrderID    = o.OrderID
        LEFT  JOIN Dress_Color dc  ON dc.DressID   = d.DressID
        WHERE o.Order_status IN ('Pending', 'In Progress')
        GROUP BY o.OrderID
        ORDER BY o.Receiving_date ASC;
    """)
    return db.query_result

# JOIN with ISA: VIP orders — show discounted pricing
func get_vip_orders() -> Array:
    db.query("""
        SELECT
            c.Name,
            v.Discount_rate,
            o.Total_price,
            ROUND(o.Total_price * (1 - v.Discount_rate / 100.0), 2) AS Discounted_price,
            o.Order_status
        FROM Customer c
        INNER JOIN VIP     v ON c.CustomerID = v.CustomerID
        INNER JOIN "Order" o ON o.CustomerID = c.CustomerID
        WHERE o.Order_status != 'Completed';
    """)
    return db.query_result

# JOIN: Cutting table — dress parts with fabric details + derived Quantity_used
func get_dress_parts_with_fabric(dress_id: int) -> Array:
    db.query("""
        SELECT
            dp.Part_name,
            f.Fabric_type,
            f.Unit_cost,
            COUNT(dp.Part_name) OVER (PARTITION BY dp.FabricID) AS Quantity_used
        FROM Dress_Parts dp
        JOIN Fabric f ON dp.FabricID = f.FabricID
        WHERE dp.DressID = %d;
    """ % dress_id)
    return db.query_result

# JOIN: Machines available for use in the 3D shop
func get_active_machines() -> Array:
    db.query("""
        SELECT si.Item_name, si.Price, m.Type, m.Speed, si.Use_Status
        FROM ShopItems si
        JOIN Machine m ON si.ItemID = m.ItemID
        WHERE si.Unlock_Status = 'Unlocked'
        ORDER BY m.Speed DESC;
    """)
    return db.query_result
```

---

### 8. Subqueries

**Theory:** A subquery is a `SELECT` statement nested inside another SQL statement. They appear in `WHERE`, `FROM`, or `SELECT` clauses. A correlated subquery references the outer query's current row.

**In This Project (`database.gd`):**

```gdscript
# Subquery in WHERE: Customers with at least one completed order
func get_returning_customers() -> Array:
    db.query("""
        SELECT Name, City FROM Customer
        WHERE CustomerID IN (
            SELECT DISTINCT CustomerID FROM "Order"
            WHERE Order_status = 'Completed'
        );
    """)
    return db.query_result

# Subquery in WHERE: Fabrics with stock below average (low-stock alert)
func get_low_stock_fabrics() -> Array:
    db.query("""
        SELECT FabricID, Fabric_type, Stock_quantity, Unit_cost
        FROM Fabric
        WHERE Stock_quantity < (
            SELECT AVG(Stock_quantity) FROM Fabric
        )
        ORDER BY Stock_quantity ASC;
    """)
    return db.query_result

# Correlated subquery: Most recent order per customer (history panel)
func get_latest_order_per_customer() -> Array:
    db.query("""
        SELECT c.Name, o.OrderID, o.Order_date, o.Total_price, o.Order_status
        FROM Customer c
        JOIN "Order" o ON c.CustomerID = o.CustomerID
        WHERE o.Order_date = (
            SELECT MAX(o2.Order_date)
            FROM "Order" o2
            WHERE o2.CustomerID = c.CustomerID
        );
    """)
    return db.query_result

# Subquery in FROM: Dress type profitability vs overall average
func get_dress_price_analysis() -> Array:
    db.query("""
        SELECT
            dt.Dress_type,
            dt.avg_price,
            (SELECT AVG(Total_price) FROM "Order"
             WHERE Order_status = 'Completed') AS overall_avg,
            ROUND(dt.avg_price - (
                SELECT AVG(Total_price) FROM "Order"
                WHERE Order_status = 'Completed'
            ), 2) AS difference
        FROM (
            SELECT d.Dress_type, AVG(o.Total_price) AS avg_price
            FROM Dress d
            JOIN "Order" o ON d.OrderID = o.OrderID
            WHERE o.Order_status = 'Completed'
            GROUP BY d.Dress_type
        ) AS dt
        ORDER BY dt.avg_price DESC;
    """)
    return db.query_result
```

---

### 9. Triggers

**Theory:** A trigger is a stored SQL procedure that fires automatically on `INSERT`, `UPDATE`, or `DELETE` events. Triggers enforce business rules at the database level, independent of application code — guaranteeing consistency even if GDScript logic has a bug.

**In This Project (`database.gd`):**

```gdscript
func _create_triggers() -> void:

    # TRIGGER: Deduct fabric stock when a dress part is cut
    db.query("""
        CREATE TRIGGER IF NOT EXISTS trg_deduct_fabric_stock
        AFTER INSERT ON Dress_Parts
        FOR EACH ROW
        BEGIN
            UPDATE Fabric
            SET Stock_quantity = Stock_quantity - 1
            WHERE FabricID = NEW.FabricID;
        END;
    """)

    # TRIGGER: Restore fabric stock if a dress part is removed
    db.query("""
        CREATE TRIGGER IF NOT EXISTS trg_restore_fabric_on_delete
        AFTER DELETE ON Dress_Parts
        FOR EACH ROW
        BEGIN
            UPDATE Fabric
            SET Stock_quantity = Stock_quantity + 1
            WHERE FabricID = OLD.FabricID;
        END;
    """)

    # TRIGGER: Recalculate order Total_price when a new dress is added
    db.query("""
        CREATE TRIGGER IF NOT EXISTS trg_update_order_total
        AFTER INSERT ON Dress
        FOR EACH ROW
        BEGIN
            UPDATE "Order"
            SET Total_price = (
                SELECT COALESCE(SUM(f.Unit_cost), 0)
                FROM Dress_Parts dp
                JOIN Fabric f ON dp.FabricID = f.FabricID
                WHERE dp.DressID = NEW.DressID
            )
            WHERE OrderID = NEW.OrderID;
        END;
    """)

    # TRIGGER: Apply VIP discount automatically when a VIP customer places an order
    db.query("""
        CREATE TRIGGER IF NOT EXISTS trg_apply_vip_discount
        AFTER INSERT ON "Order"
        FOR EACH ROW
        WHEN NEW.CustomerID IN (SELECT CustomerID FROM VIP)
        BEGIN
            UPDATE "Order"
            SET Total_price = NEW.Total_price * (
                1.0 - (SELECT Discount_rate FROM VIP
                       WHERE CustomerID = NEW.CustomerID) / 100.0
            )
            WHERE OrderID = NEW.OrderID;
        END;
    """)
```

**Gameplay Relevance:** Even if a GDScript bug bypasses the reward logic, fabric stock stays accurate and VIP discounts always apply — integrity is guaranteed at the SQL layer itself.

---

### 10. Views

**Theory:** A `VIEW` is a saved SQL query that behaves as a virtual table. Views simplify complex queries, hide schema details from application scripts, and present data pre-shaped for a specific use case.

**In This Project (`database.gd`):**

```gdscript
func _create_views() -> void:

    # VIEW: Full order board for the 3D shop's in-world display
    db.query("""
        CREATE VIEW IF NOT EXISTS v_order_board AS
        SELECT
            o.OrderID,
            c.Name              AS Customer_Name,
            c.City,
            d.Dress_type,
            GROUP_CONCAT(DISTINCT dc.Color) AS Colors,
            o.Order_date,
            o.Receiving_date,
            o.Total_price,
            o.Order_status,
            o.Payment_status,
            CASE
                WHEN o.Receiving_date < DATE('now')
                     AND o.Order_status != 'Completed' THEN 'OVERDUE'
                WHEN o.Receiving_date = DATE('now')    THEN 'DUE TODAY'
                ELSE                                        'ON TIME'
            END AS Urgency
        FROM "Order" o
        JOIN Customer   c  ON o.CustomerID = c.CustomerID
        JOIN Dress      d  ON d.OrderID    = o.OrderID
        LEFT JOIN Dress_Color dc ON dc.DressID = d.DressID
        GROUP BY o.OrderID;
    """)

    # VIEW: Player HUD — level, coins, XP bar values
    db.query("""
        CREATE VIEW IF NOT EXISTS v_player_hud AS
        SELECT
            Username,
            Level,
            Coins,
            Current_xp,
            Current_xp % 500                          AS XP_in_level,
            500 - (Current_xp % 500)                  AS XP_to_next_level,
            ROUND(Current_xp % 500 * 100.0 / 500, 1)  AS XP_percent
        FROM Player
        WHERE PlayerID = 1;
    """)

    # VIEW: Fabric inventory status for the shop management panel
    db.query("""
        CREATE VIEW IF NOT EXISTS v_inventory_status AS
        SELECT
            f.FabricID,
            f.Fabric_type,
            f.Unit_cost,
            f.Stock_quantity,
            CASE
                WHEN f.Stock_quantity = 0  THEN 'OUT OF STOCK'
                WHEN f.Stock_quantity <= 5 THEN 'LOW STOCK'
                ELSE                            'IN STOCK'
            END AS Stock_status
        FROM Fabric f;
    """)
```

**Querying views in GDScript — identical to querying a table:**

```gdscript
func get_order_board() -> Array:
    db.query("SELECT * FROM v_order_board WHERE Order_status != 'Completed';")
    return db.query_result

func get_player_hud() -> Dictionary:
    db.query("SELECT * FROM v_player_hud;")
    return db.query_result[0] if db.query_result.size() > 0 else {}

func get_inventory_status() -> Array:
    db.query("SELECT * FROM v_inventory_status ORDER BY Stock_quantity ASC;")
    return db.query_result
```

---

## 🗃 Database Schema & Relationships

### Final Relational Schema (Phase 3 Output)

```
Customer(CustomerID PK, Name, House, Street, Sector, City,
         Collar_size, Chest, Shoulder, Sleeve_length, Trouser_length, Waist)

Customer_Phone(CustomerID FK→Customer, PhoneNo)              -- multivalued attr

VIP(CustomerID PK/FK→Customer, Discount_rate)               -- ISA specialization
Rude(CustomerID PK/FK→Customer, Time_delay)                 -- ISA specialization

Order(OrderID PK, CustomerID FK→Customer, Order_date,
      Receiving_date, Payment_status, Order_status, Total_price)

Dress(DressID PK, OrderID FK→Order, Dress_type)

Dress_Color(DressID FK→Dress, Color)                        -- multivalued attr

Dress_Parts(DressID PK/FK→Dress, Part_name PK,              -- weak entity + M:N bridge
            FabricID FK→Fabric)
            ↳ Quantity_used : DERIVED — COUNT(Part_name) GROUP BY FabricID

Fabric(FabricID PK, Fabric_type, Unit_cost, Stock_quantity)

ShopItems(ItemID PK, Item_name, Price, Unlock_Status, Use_Status)

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
ShopItems                                      (DERIVED attr)
   └── Machine (ISA)

Player (standalone — tracks progression)
```

### Constraint Summary

| Table | Primary Key | Foreign Keys | Special |
|---|---|---|---|
| `Customer` | `CustomerID` | — | Root entity |
| `Customer_Phone` | `(CustomerID, PhoneNo)` | `CustomerID → Customer` | Multivalued attr |
| `VIP` | `CustomerID` | `→ Customer` | ISA — one row per VIP |
| `Rude` | `CustomerID` | `→ Customer` | ISA — one row per Rude |
| `Order` | `OrderID` | `CustomerID → Customer` | Core transaction table |
| `Dress` | `DressID` | `OrderID → Order` | CASCADE on delete |
| `Dress_Color` | `(DressID, Color)` | `DressID → Dress` | Multivalued attr |
| `Dress_Parts` | `(DressID, Part_name)` | `DressID → Dress`, `FabricID → Fabric` | Weak entity + M:N bridge |
| `Fabric` | `FabricID` | — | Independent; managed by triggers |
| `ShopItems` | `ItemID` | — | Superclass |
| `Machine` | `ItemID` | `→ ShopItems` | ISA specialization |
| `Player` | `PlayerID` | — | Singleton game record |

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
│                                   │  _create_tables()        │   │
│                                   │  _create_triggers()      │   │
│                                   │  _create_views()         │   │
│                                   │  _create_indexes()       │   │
│                                   │  + all CRUD functions    │   │
│                                   └─────────────┬────────────┘   │
│                                                 │                 │
└─────────────────────────────────────────────────┼─────────────────┘
                                                  │ SQL via godot-sqlite
                                                  ▼
                                   ┌──────────────────────────┐
                                   │       silai.db           │
                                   │   (SQLite Database)      │
                                   │                          │
                                   │  Customer / VIP / Rude   │
                                   │  Customer_Phone          │
                                   │  Order                   │
                                   │  Dress / Dress_Color     │
                                   │  Dress_Parts (+ derived) │
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
CustomerManager.gd spawns a 3D character, generates measurements.

  Database.add_customer("Ayesha Malik", "Rawalpindi", 38.0, 32.0, 14.5, 17.0, 26.0, 40.0)
  → INSERT INTO Customer (Name, City, Chest, Waist, ...) VALUES (...)
  → Returns: CustomerID = 7

  If VIP:  INSERT INTO VIP  (CustomerID, Discount_rate) VALUES (7, 15.0)
  If Rude: INSERT INTO Rude (CustomerID, Time_delay)    VALUES (7, 10)

────────────────────────────────────────────────────────────────────
STEP 2 — ORDER PLACED AT THE COUNTER
═══════════════════════════════════════
Customer reaches the 3D counter. Order is generated and saved.

  Database.create_order(7, "2026-05-25", 0.0)
  → INSERT INTO "Order" (CustomerID, Receiving_date, Total_price) VALUES (...)
  → Returns: OrderID = 42

  Database.create_dress(42, "Shalwar Kameez")
  → INSERT INTO Dress (OrderID, Dress_type) VALUES (42, 'Shalwar Kameez')
  → Returns: DressID = 18

  INSERT INTO Dress_Color (DressID, Color) VALUES (18, 'Navy Blue')

  ★ Trigger: trg_apply_vip_discount fires → Total_price auto-discounted

────────────────────────────────────────────────────────────────────
STEP 3 — PLAYER AT THE CUTTING TABLE
═══════════════════════════════════════
Player navigates to the 3D cutting table and selects fabric for each part.

  Database.add_dress_part(18, 'Body',    3)   → Fabric: Cotton
  Database.add_dress_part(18, 'Collar',  3)   → Fabric: Cotton
  Database.add_dress_part(18, 'Sleeves', 5)   → Fabric: Silk

  ★ Trigger: trg_deduct_fabric_stock fires for each insert:
    UPDATE Fabric SET Stock_quantity = Stock_quantity - 1 WHERE FabricID = 3  (×2)
    UPDATE Fabric SET Stock_quantity = Stock_quantity - 1 WHERE FabricID = 5

  Quantity_used (derived, shown in cutting table UI):
  SELECT COUNT(Part_name) ... GROUP BY FabricID
  → Cotton: 2 parts,  Silk: 1 part

────────────────────────────────────────────────────────────────────
STEP 4 — SEWING MACHINE OPERATION
════════════════════════════════════
Player interacts with a 3D sewing machine. Machine must be unlocked.

  SELECT si.Item_name, m.Speed FROM ShopItems si JOIN Machine m ON si.ItemID = m.ItemID
  WHERE si.Unlock_Status = 'Unlocked' AND si.Use_Status = 'Active'

  UPDATE "Order" SET Order_status = 'In Progress' WHERE OrderID = 42

────────────────────────────────────────────────────────────────────
STEP 5 — DELIVERY & REWARDS
══════════════════════════════
Player delivers the completed dress at the counter.

  Database.complete_order(42)
  → UPDATE "Order" SET Order_status='Completed', Payment_status='Paid' WHERE OrderID=42

  Database.reward_player(1, 150.0, 75)
  → UPDATE Player SET Coins=Coins+150, Current_xp=Current_xp+75,
                      Level=(Current_xp+75)/500+1 WHERE PlayerID=1

────────────────────────────────────────────────────────────────────
STEP 6 — HUD UPDATES IN REAL TIME
════════════════════════════════════
HUD.gd queries the view each frame cycle:

  SELECT * FROM v_player_hud
  → { Level:3, Coins:850.0, XP_in_level:225, XP_to_next_level:275, XP_percent:45.0 }

  3D HUD overlay updates: level badge, coin counter, XP progress bar.

────────────────────────────────────────────────────────────────────
STEP 7 — SESSION ENDS
═══════════════════════
SQLite commits all changes to silai.db on disk.
Next launch: database.gd opens the same file.
Every customer, order, fabric level, and coin is exactly as left.
```

---

## 📁 File Structure

```
Silai-Simulator/
│
├── project.godot                      # Godot 4 project configuration
├── silai.db                           # SQLite database (auto-created at user://)
│
├── addons/
│   └── godot-sqlite/                  # GDExtension SQLite plugin
│       ├── bin/                       # Native binaries (Win/Linux/macOS)
│       └── godot-sqlite.gdextension
│
├── autoloads/
│   └── database.gd                    # ★ Singleton — ALL SQL lives here
│                                      #   _create_tables(), _create_triggers(),
│                                      #   _create_views(), _create_indexes(),
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
│   │   ├── CuttingTable.gd           # Dress_Parts insert + derived qty display
│   │   ├── SewingMachine.tscn        # 3D sewing machine
│   │   └── SewingMachine.gd          # Machine unlock check, order progress
│   ├── ui/
│   │   ├── OrderBoard.tscn           # 3D in-world order board
│   │   ├── OrderBoard.gd             # Queries v_order_board view
│   │   ├── HUD.tscn                  # Coins, XP, Level overlay
│   │   └── HUD.gd                    # Queries v_player_hud view
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
# Total revenue from all completed orders
func get_total_revenue() -> float:
    db.query("""
        SELECT COALESCE(SUM(Total_price), 0) AS Revenue
        FROM "Order" WHERE Order_status = 'Completed';
    """)
    return db.query_result[0]["Revenue"]

# Most-ordered dress type
func get_most_popular_dress() -> String:
    db.query("""
        SELECT Dress_type, COUNT(*) AS cnt
        FROM Dress GROUP BY Dress_type
        ORDER BY cnt DESC LIMIT 1;
    """)
    return db.query_result[0]["Dress_type"] if db.query_result.size() > 0 else "None"

# Average order value split by customer type (Regular / VIP / Rude)
func get_avg_order_by_customer_type() -> Array:
    db.query("""
        SELECT
            CASE
                WHEN c.CustomerID IN (SELECT CustomerID FROM VIP)  THEN 'VIP'
                WHEN c.CustomerID IN (SELECT CustomerID FROM Rude) THEN 'Rude'
                ELSE 'Regular'
            END                          AS Customer_type,
            ROUND(AVG(o.Total_price), 2) AS Avg_order_value,
            COUNT(o.OrderID)             AS Total_orders
        FROM Customer c
        JOIN "Order" o ON c.CustomerID = o.CustomerID
        GROUP BY Customer_type
        ORDER BY Avg_order_value DESC;
    """)
    return db.query_result
```

### Index Creation for Query Optimization

```gdscript
func _create_indexes() -> void:
    db.query("CREATE INDEX IF NOT EXISTS idx_order_status   ON \"Order\"(Order_status);")
    db.query("CREATE INDEX IF NOT EXISTS idx_order_customer ON \"Order\"(CustomerID);")
    db.query("CREATE INDEX IF NOT EXISTS idx_order_deadline ON \"Order\"(Receiving_date);")
    db.query("CREATE INDEX IF NOT EXISTS idx_parts_fabric   ON Dress_Parts(FabricID);")
    db.query("CREATE INDEX IF NOT EXISTS idx_parts_dress    ON Dress_Parts(DressID);")
```

These indexes accelerate the most frequent gameplay queries — pending order lookups, join operations on `Dress_Parts`, and deadline sorting — with no overhead to the player experience.

---

## 🧩 Software Engineering Concepts

### Modular Programming

Each game system is a self-contained script with a single clear responsibility:

| Script | Does | Does Not |
|---|---|---|
| `database.gd` | All SQL: schema, triggers, views, CRUD | No scene logic, no game math |
| `OrderSystem.gd` | Order state machine transitions | No SQL, no rendering |
| `RewardSystem.gd` | Calculates coin/XP values | No DB calls, no UI updates |
| `HUD.gd` | Reads view data, updates labels | No business logic |
| `CuttingTable.gd` | Inserts Dress_Parts rows | No view rendering |

### Separation of Frontend and Backend

```
FRONTEND (Scenes + UI Scripts)           BACKEND (System Scripts + database.gd)
──────────────────────────────           ──────────────────────────────────────
Render the 3D shop environment           Manage order lifecycle state machine
Animate 3D customer characters           Generate customer data and measurements
Display order cards and urgency flags    Execute all database queries
Handle player movement and input         Calculate rewards, apply VIP discounts
Show fabric stock levels visually        Enforce stock accuracy via triggers
Update XP bar and level badge            Maintain schema, views, indexes
```

No frontend script contains SQL. No backend script touches scene nodes. All communication flows through function return values and Godot signals.

### Scalability Considerations

| Future Requirement | How the Architecture Handles It |
|---|---|
| Add a new dress type | `INSERT` a row into `Dress` — no code change needed |
| Add a new fabric | `INSERT` into `Fabric` — triggers and views adapt automatically |
| New customer subclass (e.g. Regular → Loyal) | New ISA table with FK to `Customer` — existing queries unaffected |
| Multiple save slots | Add `SaveSlot INTEGER` to `Player`, filter all queries by slot |
| Leaderboard / multiplayer | `Player.Username UNIQUE` already exists — extend with a sync layer |
| New machine category | Add to `ShopItems` + `Machine` — unlock system inherits it immediately |

---

## 🚀 Getting Started

### Prerequisites

- [Godot Engine 4.x](https://godotengine.org/download)
- [DB Browser for SQLite](https://sqlitebrowser.org/) *(optional — inspect `silai.db` during development)*

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/SolitaryRehman/Silai-Simulator.git
cd Silai-Simulator

# 2. Open Godot Engine
#    File → Import → select project.godot

# 3. Enable the plugin
#    Project → Project Settings → Plugins → godot-sqlite → Enable

# 4. Run the game
#    Press F5 or click ▶ Play
```

The database `silai.db` is created automatically on first launch. All tables, triggers, views, and indexes are initialized by `database.gd` before any gameplay begins — no manual database setup required.

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
