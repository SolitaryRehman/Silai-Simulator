# 🧵 Silai Simulator — Tailoring & Shop Simulation Game

> A feature-rich shop simulation game built in **Godot Engine** using **GDScript**, with a fully integrated **SQLite relational database** powering all game data — designed as a university-level **Database Management System (DBMS)** project.

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

**Silai Simulator** is a 2D shop simulation game where the player manages a tailoring business. Customers walk into the shop, place clothing orders, and the player must complete those orders through dedicated gameplay systems — all while earning coins, gaining experience points, and expanding their inventory.

### Gameplay Loop

```
Customer Enters Shop
       ↓
Order is Placed (clothing type, fabric, deadline)
       ↓
Player Completes the Order (cutting, sewing, finishing)
       ↓
Order is Delivered → Rewards Granted (Coins + XP)
       ↓
Player Levels Up → Unlocks New Items / Upgrades Shop
```

### Core Systems

| System | Description |
|---|---|
| **Customer Generation** | Customers are procedurally generated with unique names, preferences, and patience timers |
| **Order Management** | Each order tracks clothing type, fabric, color, deadline, and status |
| **Reward System** | Completing orders on time grants bonus coins; late deliveries reduce reward |
| **XP & Leveling** | Player earns XP per order; leveling up unlocks new clothing types and shop upgrades |
| **Inventory System** | Fabrics and materials are tracked in stock; orders consume inventory |
| **Persistent Storage** | All game state is saved to SQLite — progress survives between sessions |

---

## 🛠 Technologies Used

| Technology | Role |
|---|---|
| **Godot Engine 4.x** | Game engine — scene management, rendering, physics, input handling |
| **GDScript** | Primary scripting language for all game logic, UI, and database operations |
| **SQLite (via godot-sqlite plugin)** | Relational database for all persistent game data |
| **DB Browser for SQLite** | Visual database administration and schema design tool |
| **Git & GitHub** | Version control and project hosting |

### Why Godot?

Godot's node-based scene system maps naturally to a shop simulation. Each UI panel, customer sprite, and gameplay mechanic is an isolated scene — making the project modular and easy to extend.

### Why GDScript?

GDScript is Godot's native scripting language, tightly integrated with the engine's node system. Its Python-like syntax is clean and readable, making it ideal for rapid game development with complex data flows.

---

## 🗄 Database Integration

### Why SQLite?

SQLite was chosen for the following reasons:

- **Serverless**: No separate database process is needed — the entire database is a single `.db` file embedded in the project.
- **Lightweight**: Perfect for a desktop game with moderate data complexity.
- **SQL Standard**: Supports full relational SQL — joins, subqueries, triggers, views, and transactions.
- **Persistent Storage**: Data survives between sessions without a cloud backend.
- **Portable**: The `.db` file ships with the game, making distribution simple.

### Connecting SQLite to Godot

SQLite is connected using the **[godot-sqlite](https://github.com/2shady4u/godot-sqlite)** GDExtension plugin by 2shady4u, which wraps the native SQLite3 C library and exposes it as a GDScript class.

**Installation:**
1. Download the plugin from the Godot Asset Library (`godot-sqlite`)
2. Enable it under `Project → Project Settings → Plugins`
3. The plugin adds a `SQLite` class available throughout GDScript

**Database Initialization (`DatabaseManager.gd`):**

```gdscript
extends Node

const DB_PATH = "user://silai_simulator.db"
var db: SQLite

func _ready():
    db = SQLite.new()
    db.path = DB_PATH
    db.verbosity_level = SQLite.QUIET
    db.open_db()
    _initialize_schema()

func _initialize_schema():
    db.query("""
        CREATE TABLE IF NOT EXISTS customers (
            customer_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT NOT NULL,
            patience      INTEGER DEFAULT 100,
            visit_date    TEXT DEFAULT (DATE('now'))
        );
    """)
    # Additional table creation queries follow...
```

> **Note:** The database file is stored in `user://` — Godot's user data directory — ensuring read/write access on all platforms including Android and Windows.

### Executing Queries from GDScript

All database operations are routed through `DatabaseManager.gd`, which is registered as an **Autoload (Singleton)** so any scene can call it without instantiating it manually.

```gdscript
# Inserting a new order
func insert_order(customer_id: int, clothing_type: String, fabric: String, deadline: String) -> int:
    var query = """
        INSERT INTO orders (customer_id, clothing_type, fabric, status, deadline)
        VALUES ({cid}, '{ctype}', '{fab}', 'pending', '{dl}');
    """.format({"cid": customer_id, "ctype": clothing_type, "fab": fabric, "dl": deadline})
    db.query(query)
    return db.last_insert_rowid

# Retrieving all pending orders
func get_pending_orders() -> Array:
    db.query("SELECT * FROM orders WHERE status = 'pending' ORDER BY deadline ASC;")
    return db.query_result
```

Results are returned as an `Array` of `Dictionary` objects, where each dictionary maps column names to values — making them immediately usable in GDScript logic and UI binding.

---

## 📚 DBMS Concepts Applied

### 1. Data Definition Language (DDL)

**Theory:** DDL statements define the structure of the database — creating, modifying, or dropping tables, columns, constraints, and indexes.

**In This Project:**
The entire schema is created on first launch using `CREATE TABLE IF NOT EXISTS` statements inside `DatabaseManager._initialize_schema()`. This ensures the database self-initializes without requiring external setup.

```sql
-- DDL: Creating the orders table
CREATE TABLE IF NOT EXISTS orders (
    order_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id   INTEGER NOT NULL,
    clothing_type TEXT NOT NULL,
    fabric        TEXT NOT NULL,
    color         TEXT,
    status        TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'in_progress', 'completed', 'failed')),
    coins_reward  INTEGER DEFAULT 50,
    xp_reward     INTEGER DEFAULT 20,
    deadline      TEXT NOT NULL,
    created_at    TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);
```

**Gameplay Relevance:** When a new clothing type is added to the game, a single `ALTER TABLE` or schema migration script extends the database without breaking existing saved data.

---

### 2. Data Manipulation Language (DML)

**Theory:** DML covers `SELECT`, `INSERT`, `UPDATE`, and `DELETE` — the four operations for reading and modifying data in tables.

**In This Project:** Every gameplay action maps to a DML operation.

```sql
-- INSERT: Customer places a new order
INSERT INTO orders (customer_id, clothing_type, fabric, coins_reward, deadline)
VALUES (7, 'Shalwar Kameez', 'Cotton', 120, '2024-12-05');

-- UPDATE: Player marks an order as complete
UPDATE orders
SET status = 'completed', completed_at = DATETIME('now')
WHERE order_id = 42;

-- DELETE: Remove expired incomplete orders
DELETE FROM orders
WHERE status = 'pending' AND deadline < DATE('now');

-- SELECT: Load player's current stats for HUD display
SELECT level, total_xp, coins FROM player_stats WHERE player_id = 1;
```

---

### 3. Entity Relationship Modeling (ERM / EERM)

**Theory:** ERM defines entities (tables), their attributes (columns), and the relationships between them (foreign keys). Extended ERM (EERM) adds concepts like inheritance, weak entities, and multi-valued attributes.

**In This Project:**

```
CUSTOMER (customer_id PK, name, patience, visit_date)
    ||——<  ORDER (order_id PK, customer_id FK, clothing_type, fabric, status, ...)
                ||——<  ORDER_ITEM (item_id PK, order_id FK, fabric_id FK, quantity)
                              >——||  INVENTORY (fabric_id PK, fabric_name, stock_qty, unit_price)

PLAYER_STATS (player_id PK, level, total_xp, coins)
    ||——<  XP_LOG (log_id PK, player_id FK, xp_earned, reason, timestamp)
    ||——<  COIN_LOG (log_id PK, player_id FK, amount, transaction_type, timestamp)

CLOTHING_CATALOG (clothing_id PK, name, base_price, xp_value, unlock_level)
```

**Key Relationships:**
- A `CUSTOMER` can have **many** `ORDERS` (One-to-Many)
- An `ORDER` requires **many** `ORDER_ITEMS`, each referencing an `INVENTORY` fabric (Many-to-Many resolved via junction table)
- `PLAYER_STATS` has **many** `XP_LOG` and `COIN_LOG` entries (audit trail)

---

### 4. Normalization

**Theory:** Normalization eliminates data redundancy and insertion/update/deletion anomalies by organizing tables to satisfy normal forms (1NF → 2NF → 3NF → BCNF).

**In This Project:**

| Normal Form | Violation Example (Before) | Fix Applied |
|---|---|---|
| **1NF** | Storing `"Cotton,Silk,Wool"` in one column | Separate `ORDER_ITEM` table with one fabric per row |
| **2NF** | `fabric_price` stored in `orders` (depends only on fabric, not order) | Moved `unit_price` to `INVENTORY` table |
| **3NF** | `player_level_name` stored in `orders` (depends on level, not order) | Moved to `PLAYER_STATS`; orders reference player_id only |

**Result:** The normalized schema means changing a fabric's price requires updating exactly **one row** in `INVENTORY` — it automatically reflects in all past and future order calculations.

---

### 5. Functional Dependencies & Database Anomalies

**Theory:**
- A **Functional Dependency** (FD) means that knowing column A uniquely determines column B: `A → B`
- **Anomalies** arise when data is poorly structured:
  - **Insertion Anomaly**: Can't add a fabric without an existing order
  - **Update Anomaly**: Changing fabric price requires updating every order row
  - **Deletion Anomaly**: Deleting all orders for a customer loses their fabric preferences

**In This Project:**

```
order_id → customer_id, clothing_type, status, deadline    (Full FD — good)
fabric_id → fabric_name, stock_qty, unit_price             (Full FD — good)
customer_id → name, patience                               (Full FD — good)
```

By ensuring every non-key attribute depends **only** on the whole primary key (2NF) and **not** on another non-key attribute (3NF), all three anomaly types are eliminated.

---

### 6. Joins

**Theory:** Joins combine rows from two or more tables based on a related column. Types include INNER JOIN, LEFT JOIN, RIGHT JOIN, and FULL OUTER JOIN.

**In This Project:**

```sql
-- INNER JOIN: Get all pending orders with customer names (for the order board UI)
SELECT
    o.order_id,
    c.name        AS customer_name,
    o.clothing_type,
    o.fabric,
    o.deadline,
    o.coins_reward
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
WHERE o.status = 'pending'
ORDER BY o.deadline ASC;
```

```sql
-- LEFT JOIN: Show all customers and their orders (including customers with no orders yet)
SELECT
    c.name,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.coins_reward), 0) AS potential_earnings
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;
```

**Gameplay Relevance:** The order board UI is populated entirely from join queries — the GDScript simply calls `db.query_result` and maps each dictionary directly to a UI card.

---

### 7. Subqueries

**Theory:** A subquery is a `SELECT` statement nested inside another SQL statement. They can appear in `WHERE`, `FROM`, or `SELECT` clauses.

**In This Project:**

```sql
-- Subquery in WHERE: Find customers who have at least one completed order
SELECT name FROM customers
WHERE customer_id IN (
    SELECT DISTINCT customer_id FROM orders
    WHERE status = 'completed'
);
```

```sql
-- Correlated Subquery: Get the most recent order per customer
SELECT c.name, o.clothing_type, o.created_at
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.created_at = (
    SELECT MAX(created_at)
    FROM orders
    WHERE customer_id = c.customer_id
);
```

```sql
-- Subquery in FROM (Derived Table): Average reward per clothing type vs player's earnings
SELECT
    clothing_type,
    avg_reward,
    (SELECT SUM(coins_reward) FROM orders WHERE status = 'completed') AS total_earned
FROM (
    SELECT clothing_type, AVG(coins_reward) AS avg_reward
    FROM orders
    GROUP BY clothing_type
) AS type_averages;
```

---

### 8. Triggers

**Theory:** A trigger is a stored procedure that automatically executes in response to `INSERT`, `UPDATE`, or `DELETE` events on a table.

**In This Project:**

```sql
-- TRIGGER: Auto-award XP when an order is marked complete
CREATE TRIGGER IF NOT EXISTS award_xp_on_completion
AFTER UPDATE ON orders
FOR EACH ROW
WHEN NEW.status = 'completed' AND OLD.status != 'completed'
BEGIN
    UPDATE player_stats
    SET total_xp = total_xp + NEW.xp_reward,
        level    = CAST((total_xp + NEW.xp_reward) / 500 AS INTEGER) + 1
    WHERE player_id = 1;

    INSERT INTO xp_log (player_id, xp_earned, reason, timestamp)
    VALUES (1, NEW.xp_reward, 'Order #' || NEW.order_id || ' completed', DATETIME('now'));
END;
```

```sql
-- TRIGGER: Deduct inventory when an order item is created
CREATE TRIGGER IF NOT EXISTS deduct_inventory_on_order
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE inventory
    SET stock_qty = stock_qty - NEW.quantity
    WHERE fabric_id = NEW.fabric_id;
END;
```

**Gameplay Relevance:** Triggers ensure game logic stays **consistent at the database level** — even if a bug in GDScript forgets to award XP, the trigger fires automatically whenever an order status changes.

---

### 9. Views

**Theory:** A `VIEW` is a saved SQL query that behaves like a virtual table. It simplifies complex queries and restricts access to raw table data.

**In This Project:**

```sql
-- VIEW: Unified order summary for the shop dashboard
CREATE VIEW IF NOT EXISTS v_order_summary AS
SELECT
    o.order_id,
    c.name              AS customer_name,
    o.clothing_type,
    o.fabric,
    o.status,
    o.deadline,
    o.coins_reward,
    o.xp_reward,
    CASE
        WHEN o.deadline < DATE('now') AND o.status != 'completed' THEN 'OVERDUE'
        WHEN o.deadline = DATE('now') THEN 'DUE TODAY'
        ELSE 'ON TIME'
    END AS urgency_flag
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id;
```

```sql
-- VIEW: Player progress summary for HUD
CREATE VIEW IF NOT EXISTS v_player_hud AS
SELECT
    ps.level,
    ps.total_xp,
    ps.coins,
    (ps.total_xp % 500) AS xp_in_current_level,
    (500 - (ps.total_xp % 500)) AS xp_to_next_level,
    COUNT(DISTINCT o.order_id) AS completed_orders
FROM player_stats ps
LEFT JOIN orders o ON o.status = 'completed'
WHERE ps.player_id = 1;
```

**In GDScript:**

```gdscript
# Query the view as if it were a regular table
func get_order_summary() -> Array:
    db.query("SELECT * FROM v_order_summary WHERE status = 'pending';")
    return db.query_result
```

---

## 🗃 Database Schema & Relationships

### Tables

| Table | Primary Key | Description |
|---|---|---|
| `customers` | `customer_id` | Generated customer profiles |
| `orders` | `order_id` | Clothing orders placed by customers |
| `order_items` | `item_id` | Individual fabric items per order |
| `inventory` | `fabric_id` | Available fabrics and stock levels |
| `clothing_catalog` | `clothing_id` | Master list of clothing types |
| `player_stats` | `player_id` | Player level, XP, and coin balance |
| `xp_log` | `log_id` | Audit log of all XP gains |
| `coin_log` | `log_id` | Audit log of all coin transactions |

### Relationships Diagram

```
customers ──────────────< orders >──────────────< order_items >────────── inventory
    PK: customer_id          PK: order_id             PK: item_id               PK: fabric_id
                             FK: customer_id           FK: order_id
                                                       FK: fabric_id

player_stats ───────────< xp_log
    PK: player_id            FK: player_id

player_stats ───────────< coin_log
    PK: player_id            FK: player_id
```

### Foreign Key Constraints

```sql
-- orders references customers
FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE

-- order_items references both orders and inventory
FOREIGN KEY (order_id)  REFERENCES orders(order_id) ON DELETE CASCADE
FOREIGN KEY (fabric_id) REFERENCES inventory(fabric_id)

-- xp_log and coin_log reference player_stats
FOREIGN KEY (player_id) REFERENCES player_stats(player_id)
```

---

## 🏗 Workflow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GODOT ENGINE                         │
│                                                             │
│  ┌─────────────┐    signals    ┌──────────────────────┐    │
│  │  GUI Scenes │ ─────────────>│   GDScript Logic     │    │
│  │  (.tscn)    │ <─────────────│   (*.gd files)       │    │
│  └─────────────┘   UI updates  └──────────┬───────────┘    │
│                                           │                 │
│                                    function calls           │
│                                           │                 │
│                                           ▼                 │
│                              ┌────────────────────────┐    │
│                              │   DatabaseManager.gd   │    │
│                              │   (Autoload Singleton) │    │
│                              └────────────┬───────────┘    │
│                                           │                 │
│                                     SQL queries             │
│                                           │                 │
└───────────────────────────────────────────┼─────────────────┘
                                            │
                                            ▼
                              ┌─────────────────────────┐
                              │   SQLite Database       │
                              │  silai_simulator.db     │
                              │                         │
                              │  • customers            │
                              │  • orders               │
                              │  • order_items          │
                              │  • inventory            │
                              │  • player_stats         │
                              │  • xp_log / coin_log    │
                              └─────────────────────────┘
```

### Scene ↔ Script ↔ Database Communication

1. **GUI Scenes** (`.tscn`) contain nodes (buttons, labels, lists) with no business logic.
2. Each scene has an **attached GDScript** (`.gd`) that handles its specific logic.
3. Scripts never query the database directly — they call **`DatabaseManager`** functions.
4. `DatabaseManager` executes SQL, receives results as `Array[Dictionary]`, and returns them.
5. Scripts update GUI nodes using the returned data.

---

## 🔄 Functional Flow

### Step-by-Step: Customer Order Lifecycle

```
Step 1: CUSTOMER GENERATION
────────────────────────────
CustomerManager.gd generates a customer (random name, patience, clothing preference).
→ INSERT INTO customers (name, patience) VALUES ('Ayesha', 80);
→ Returns new customer_id

Step 2: ORDER GENERATION
────────────────────────────
OrderSystem.gd creates an order for that customer.
→ INSERT INTO orders (customer_id, clothing_type, fabric, deadline, coins_reward)
  VALUES (7, 'Dupatta', 'Silk', '2024-12-10', 90);
→ Returns order_id; Order card appears in GUI

Step 3: PLAYER ACCEPTS ORDER
────────────────────────────
Player clicks "Accept" on the order card.
→ UPDATE orders SET status = 'in_progress' WHERE order_id = 42;
→ Gameplay mini-game begins (cutting, sewing, finishing)

Step 4: INVENTORY CONSUMED
────────────────────────────
Order system checks and deducts fabric stock.
→ Trigger: deduct_inventory_on_order fires automatically
→ UPDATE inventory SET stock_qty = stock_qty - 2 WHERE fabric_id = 3;

Step 5: ORDER COMPLETED
────────────────────────────
Player finishes all gameplay steps and clicks "Deliver".
→ UPDATE orders SET status = 'completed', completed_at = DATETIME('now')
  WHERE order_id = 42;
→ Trigger: award_xp_on_completion fires automatically
→ UPDATE player_stats SET total_xp = total_xp + 20, coins = coins + 90 ...

Step 6: GUI UPDATES
────────────────────────────
HUD script queries v_player_hud view.
→ SELECT * FROM v_player_hud;
→ Level label, XP bar, and coin counter update in real time.

Step 7: DATA PERSISTS
────────────────────────────
All data is committed to silai_simulator.db on disk.
Next game session loads from the same file — no progress is lost.
```

---

## 📁 File Structure

```
Silai-Simulator/
│
├── project.godot                  # Godot project configuration
├── silai_simulator.db             # SQLite database (auto-created at runtime)
│
├── addons/
│   └── godot-sqlite/              # SQLite GDExtension plugin
│       ├── bin/                   # Compiled native binaries
│       └── godot-sqlite.gdextension
│
├── autoloads/
│   └── DatabaseManager.gd         # ★ Singleton: all SQL operations live here
│
├── scenes/
│   ├── main_menu/
│   │   ├── MainMenu.tscn
│   │   └── MainMenu.gd            # Scene logic, calls DatabaseManager
│   ├── shop/
│   │   ├── ShopScene.tscn
│   │   └── ShopScene.gd           # Core gameplay loop
│   ├── order_board/
│   │   ├── OrderBoard.tscn
│   │   └── OrderBoard.gd          # Displays pending orders from DB
│   ├── customer/
│   │   ├── Customer.tscn
│   │   └── CustomerManager.gd     # Customer generation + DB insert
│   └── hud/
│       ├── HUD.tscn
│       └── HUD.gd                 # Reads v_player_hud view for display
│
├── scripts/
│   ├── OrderSystem.gd             # Order creation, status updates
│   ├── InventorySystem.gd         # Stock queries and deductions
│   ├── RewardSystem.gd            # XP and coin calculations
│   └── LevelSystem.gd             # Level-up detection and unlocks
│
└── assets/
    ├── sprites/                   # Character and clothing artwork
    ├── fonts/
    └── sounds/
```

### Key Script Responsibilities

| Script | Responsibility |
|---|---|
| `DatabaseManager.gd` | Opens DB, runs all queries, returns results. Single source of truth for data access. |
| `CustomerManager.gd` | Generates customers using RNG, inserts them into DB, spawns sprites |
| `OrderSystem.gd` | Creates orders in DB, tracks status transitions, triggers reward flow |
| `InventorySystem.gd` | Checks stock availability before accepting orders, displays low-stock warnings |
| `RewardSystem.gd` | Calculates coin/XP values (including late-penalty logic), writes to DB |
| `HUD.gd` | Polls the `v_player_hud` view every few seconds and updates all HUD labels |

---

## ⚙ Advanced Query System

### CRUD Operations

```gdscript
# ── CREATE ──────────────────────────────────────────────
func add_customer(name: String, patience: int) -> int:
    db.query("INSERT INTO customers (name, patience) VALUES ('%s', %d);" % [name, patience])
    return db.last_insert_rowid

# ── READ ─────────────────────────────────────────────────
func get_active_orders() -> Array:
    db.query("""
        SELECT o.order_id, c.name, o.clothing_type, o.deadline, o.coins_reward
        FROM orders o
        JOIN customers c ON o.customer_id = c.customer_id
        WHERE o.status IN ('pending', 'in_progress')
        ORDER BY o.deadline ASC
        LIMIT 10;
    """)
    return db.query_result

# ── UPDATE ───────────────────────────────────────────────
func complete_order(order_id: int) -> void:
    db.query("""
        UPDATE orders
        SET status = 'completed', completed_at = DATETIME('now')
        WHERE order_id = %d;
    """ % order_id)

# ── DELETE ───────────────────────────────────────────────
func purge_old_customers() -> void:
    db.query("""
        DELETE FROM customers
        WHERE customer_id NOT IN (
            SELECT DISTINCT customer_id FROM orders
        )
        AND visit_date < DATE('now', '-7 days');
    """)
```

### Aggregate Functions

```sql
-- Total coins earned from completed orders this session
SELECT SUM(coins_reward) AS session_earnings
FROM orders
WHERE status = 'completed' AND DATE(completed_at) = DATE('now');

-- Most popular clothing type ordered
SELECT clothing_type, COUNT(*) AS order_count
FROM orders
GROUP BY clothing_type
ORDER BY order_count DESC
LIMIT 1;

-- Average customer patience at time of order
SELECT AVG(c.patience) AS avg_patience
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id;
```

### Query Optimization

- **Indexes** on `orders.status`, `orders.customer_id`, and `orders.deadline` speed up the most frequent queries.
- **Views** (`v_order_summary`, `v_player_hud`) pre-join tables so the HUD doesn't run expensive joins every frame.
- **LIMIT clauses** prevent loading unbounded result sets into GDScript arrays.
- **`query_result` vs `query_result_by_reference`**: The project uses `query_result` (by value) to safely use results in loops without them being overwritten by the next query.

```sql
-- Index creation (in DDL initialization)
CREATE INDEX IF NOT EXISTS idx_orders_status   ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_deadline ON orders(deadline);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
```

---

## 🧩 Software Engineering Concepts

### Modular Programming

Each game system is a **self-contained GDScript file** with a well-defined interface:

- `OrderSystem.gd` knows nothing about rendering — it only manages order data.
- `HUD.gd` knows nothing about database queries — it only reads returned arrays and updates labels.
- Changing the database schema requires updating only `DatabaseManager.gd` and the relevant system script — not every scene.

### Separation of Frontend and Backend Logic

```
Frontend (Scenes + HUD scripts)     Backend (System scripts + DatabaseManager)
─────────────────────────────       ──────────────────────────────────────────
Render order cards                  Query and return order data
Show XP bar progress                Calculate XP values and update DB
Display customer sprite             Generate customer stats and insert to DB
Handle button clicks                Execute status updates on DB
```

Frontend scripts **never contain SQL**. Backend scripts **never touch scene nodes**. Communication happens through return values and Godot signals.

### Reusable Database Functions

`DatabaseManager.gd` exposes a clean public API:

```gdscript
# Any script anywhere in the project can call:
DatabaseManager.get_active_orders()
DatabaseManager.complete_order(order_id)
DatabaseManager.get_player_stats()
DatabaseManager.add_inventory(fabric_id, quantity)
```

No script duplicates query logic. If the orders table is renamed, only `DatabaseManager.gd` needs updating.

### Scalability Considerations

| Consideration | Design Decision |
|---|---|
| New clothing types | Add a row to `clothing_catalog` — no code changes needed |
| New currency type | Add a column to `player_stats` and a new log table |
| Multiplayer future | Replace `player_id = 1` hardcode with a session-based player lookup |
| Save slots | Add a `save_slot` column to `player_stats` and filter all queries by it |
| Cloud sync | Export the `.db` file — SQLite databases are portable binary files |

---

## 🚀 Getting Started

### Prerequisites

- [Godot Engine 4.x](https://godotengine.org/download)
- [DB Browser for SQLite](https://sqlitebrowser.org/) *(optional — for inspecting the database)*

### Installation

```bash
# Clone the repository
git clone https://github.com/SolitaryRehman/Silai-Simulator.git

# Open Godot Engine
# Click "Import" and select the project.godot file
# Enable the godot-sqlite plugin: Project → Project Settings → Plugins
# Press F5 to run
```

The SQLite database (`silai_simulator.db`) is created automatically on first launch inside Godot's `user://` directory.

---

## 👥 Author

**SolitaryRehman**
GitHub: [@SolitaryRehman](https://github.com/SolitaryRehman)

---

## 📄 License

This project is submitted as a university DBMS course project. All game assets and code are original work by the author unless otherwise noted.

---

*Built with ❤️ using Godot Engine + SQLite — where every stitch is a database transaction.*
