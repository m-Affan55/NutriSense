"""
build_food_db.py
Converts nutriSenseData.csv → foods.db (SQLite)
Run once:  python scripts/build_food_db.py

Creates:
  backend/data/foods.db
  Table: foods
  Index: idx_foods_code  (on barcode)
"""
import sqlite3
import csv
import os
import time

BASE_DIR   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH   = os.path.join(BASE_DIR, 'data', 'nutriSenseData.csv')
DB_PATH    = os.path.join(BASE_DIR, 'data', 'foods.db')

def safe_float(val):
    try:
        return float(val) if val and val.strip() else None
    except ValueError:
        return None

def build():
    if not os.path.exists(CSV_PATH):
        print(f"ERROR: CSV not found at {CSV_PATH}")
        return

    print(f"Input : {CSV_PATH}")
    print(f"Output: {DB_PATH}")
    print()

    # Remove existing DB so we start fresh
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        print("Removed old foods.db")

    conn = sqlite3.connect(DB_PATH)
    cur  = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS foods (
            code              TEXT PRIMARY KEY,
            product_name      TEXT,
            brands            TEXT,
            calories_kcal     REAL,
            fat_g             REAL,
            carbs_g           REAL,
            protein_g         REAL,
            ingredients_text  TEXT,
            allergens_en      TEXT
        )
    """)

    BATCH     = 10_000
    total     = 0
    skipped   = 0
    start     = time.time()
    batch_buf = []

    print("Importing rows ...")

    with open(CSV_PATH, 'r', encoding='utf-8-sig', errors='replace') as f:
        reader = csv.DictReader(f)
        for row in reader:
            code = row.get('code', '').strip()
            if not code:
                skipped += 1
                continue

            name = row.get('product_name', '').strip()
            if not name:
                # Fall back to brands if product_name is empty
                name = row.get('brands', '').strip()
            if not name:
                skipped += 1
                continue

            batch_buf.append((
                code,
                name,
                row.get('brands', '').strip(),
                safe_float(row.get('calories_kcal_100g', '')),
                safe_float(row.get('fat_100g', '')),
                safe_float(row.get('carbohydrates_100g', '')),
                safe_float(row.get('proteins_100g', '')),
                row.get('ingredients_text', '').strip(),
                row.get('allergens_en', '').strip(),
            ))

            if len(batch_buf) >= BATCH:
                cur.executemany("""
                    INSERT OR REPLACE INTO foods
                    (code, product_name, brands, calories_kcal, fat_g, carbs_g, protein_g, ingredients_text, allergens_en)
                    VALUES (?,?,?,?,?,?,?,?,?)
                """, batch_buf)
                conn.commit()
                total += len(batch_buf)
                batch_buf.clear()
                elapsed = time.time() - start
                print(f"  {total:,} rows inserted  [{elapsed:.1f}s]")

    # Insert remaining
    if batch_buf:
        cur.executemany("""
            INSERT OR REPLACE INTO foods
            (code, product_name, brands, calories_kcal, fat_g, carbs_g, protein_g, ingredients_text, allergens_en)
            VALUES (?,?,?,?,?,?,?,?,?)
        """, batch_buf)
        conn.commit()
        total += len(batch_buf)

    # Create index for fast barcode lookups
    print("\nCreating index on code ...")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_foods_code ON foods (code)")
    conn.commit()

    # Stats
    cur.execute("SELECT COUNT(*) FROM foods")
    db_count = cur.fetchone()[0]
    conn.close()

    elapsed = time.time() - start
    db_size = os.path.getsize(DB_PATH) / (1024 * 1024)
    csv_size = os.path.getsize(CSV_PATH) / (1024 * 1024)

    print()
    print("=" * 50)
    print(f"  Done in      : {elapsed:.1f}s")
    print(f"  CSV size     : {csv_size:.1f} MB")
    print(f"  DB size      : {db_size:.1f} MB")
    print(f"  Rows in DB   : {db_count:,}")
    print(f"  Rows skipped : {skipped:,}")
    print(f"  DB saved to  : {DB_PATH}")
    print("=" * 50)

if __name__ == '__main__':
    build()
