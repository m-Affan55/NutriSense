"""
food_db_service.py
Fast SQLite-based barcode lookup service.

Lookup order in scan_barcode endpoint:
  1. Query foods.db  (instant, offline, free)
  2. Fallback → Gemini AI  (for unknown barcodes)
"""
import sqlite3
import os
import re
from typing import Optional

DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       '..', 'data', 'foods.db')
DB_PATH = os.path.normpath(DB_PATH)

# Module-level connection (reused across requests for performance)
_conn: Optional[sqlite3.Connection] = None


def _get_conn() -> Optional[sqlite3.Connection]:
    global _conn
    if not os.path.exists(DB_PATH):
        return None
    if _conn is None:
        _conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        _conn.row_factory = sqlite3.Row
    return _conn


class FoodDBService:

    @staticmethod
    def lookup(barcode: str) -> Optional[dict]:
        """
        Look up a barcode in the local SQLite foods database.
        Returns None if not found or DB unavailable.

        The DB stores codes as zero-padded strings of varying lengths.
        We try several normalizations to maximize match rate.
        """
        conn = _get_conn()
        if conn is None:
            return None

        code = barcode.strip()
        if not code:
            return None

        # Build candidate list of barcode formats to try
        candidates = set()
        candidates.add(code)                          # exact as-is

        numeric = code.lstrip('0') or '0'             # strip leading zeros

        # Pad to common standard lengths: 13 (EAN-13), 12 (UPC-A), 11, 8 (EAN-8)
        for length in (13, 12, 11, 8):
            if len(code) <= length:
                candidates.add(code.zfill(length))    # zero-pad
            if len(numeric) <= length:
                candidates.add(numeric.zfill(length)) # strip then re-pad

        try:
            cur = conn.cursor()
            placeholders = ','.join('?' * len(candidates))
            # Order so rows with complete macros come first (CASE WHEN NULL = 0, non-null = 1).
            # This handles dataset duplicates where one row has macros and another doesn't.
            cur.execute(
                f"""SELECT * FROM foods
                    WHERE code IN ({placeholders})
                    ORDER BY
                        (CASE WHEN fat_g   IS NOT NULL THEN 1 ELSE 0 END) +
                        (CASE WHEN carbs_g IS NOT NULL THEN 1 ELSE 0 END) +
                        (CASE WHEN protein_g IS NOT NULL THEN 1 ELSE 0 END) DESC
                    LIMIT 1""",
                tuple(candidates)
            )
            row = cur.fetchone()
            return dict(row) if row else None
        except Exception:
            return None

    @staticmethod
    def is_macro_complete(food_row: Optional[dict]) -> bool:
        """
        Evaluates whether a database row has valid, complete nutritional macros.
        Returns:
          - False if any macro is NULL (missing data)
          - False if Calories > 50 but all macros are 0.0 (corrupt/anomalous data)
          - True  if legitimate zero-calorie item (Tea, Water, Coffee, Salt) with <= 25 kcal and 0.0 macros
          - True  if real positive macros exist
        """
        if not food_row:
            return False

        fat = food_row.get('fat_g')
        carbs = food_row.get('carbs_g')
        protein = food_row.get('protein_g')
        cal = food_row.get('calories_kcal')

        # 1. Any macro is NULL -> genuinely missing in dataset
        if fat is None or carbs is None or protein is None:
            return False

        try:
            f, c, p = float(fat), float(carbs), float(protein)
            cal_val = float(cal) if cal is not None else 0.0
        except (ValueError, TypeError):
            return False

        # 2. Calories > 50 but all macros are 0.0 -> anomaly, needs AI correction
        if cal_val > 50 and f == 0.0 and c == 0.0 and p == 0.0:
            return False

        # 3. Zero/low calorie items (Tea, Water, Black Coffee, Salt) with 0.0 macros -> legitimate
        if cal_val <= 25 and f == 0.0 and c == 0.0 and p == 0.0:
            return True

        # 4. At least one positive macro value
        if f > 0 or c > 0 or p > 0:
            return True

        return False

    @staticmethod
    def check_allergens(food_row: dict, profile: Optional[dict]) -> list[str]:
        """
        Cross-check food allergens & ingredients against the user's health profile.
        Returns a list of user-friendly warning strings.
        """
        if not profile:
            return []

        warnings = []

        allergens_text = (food_row.get('allergens_en') or '').lower()
        ingredients    = (food_row.get('ingredients_text') or '').lower()
        combined       = allergens_text + ' ' + ingredients

        # Check user's listed allergies
        user_allergies = profile.get('allergies') or profile.get('dietary_restrictions') or []
        for allergy in user_allergies:
            if not allergy:
                continue
            allergy_lower = allergy.lower()
            if allergy_lower in combined:
                warnings.append(
                    f"⚠️ Contains {allergy.title()} — conflicts with your allergy profile"
                )

        # Check medical conditions with known dietary rules
        conditions = profile.get('medical_conditions') or []
        condition_keywords = {
            'diabetes':       (['sugar', 'glucose', 'fructose', 'corn syrup', 'dextrose'], 'high sugar content'),
            'hypertension':   (['salt', 'sodium', 'msg', 'monosodium glutamate'],           'high sodium/salt content'),
            'celiac':         (['wheat', 'gluten', 'barley', 'rye', 'malt'],                'contains gluten'),
            'lactose':        (['milk', 'lactose', 'dairy', 'cheese', 'whey', 'cream'],     'contains dairy/lactose'),
            'peanut allergy': (['peanut', 'groundnut', 'arachis oil'],                      'contains peanuts'),
            'nut allergy':    (['almond', 'cashew', 'walnut', 'hazelnut', 'pistachio',
                                'pecan', 'macadamia'],                                       'contains tree nuts'),
        }

        for condition in conditions:
            condition_lower = condition.lower()
            for key, (triggers, label) in condition_keywords.items():
                if key in condition_lower:
                    for trigger in triggers:
                        if trigger in combined:
                            warnings.append(
                                f"⚠️ {label.capitalize()} detected — may not be suitable for your {condition}"
                            )
                            break  # one warning per condition is enough

        return warnings

    @staticmethod
    def format_result(food_row: dict, profile: Optional[dict] = None) -> dict:
        """
        Convert a DB row into the same response shape the endpoint returns,
        so the Flutter app needs no changes.
        """
        name = food_row.get('product_name') or ''
        brand = food_row.get('brands') or ''
        # Show "Brand · Product" if both available and different
        display_name = name
        if brand and brand.lower() not in name.lower():
            display_name = f"{brand} · {name}"

        product_data = {
            'product_name':    display_name,
            'calories':        round(food_row.get('calories_kcal') or 0),
            'protein_g':       round(float(food_row.get('protein_g')  or 0), 1),
            'carbs_g':         round(float(food_row.get('carbs_g')    or 0), 1),
            'fat_g':           round(float(food_row.get('fat_g')      or 0), 1),
            'ingredients':     food_row.get('ingredients_text') or 'No ingredient information available',
            'allergens':       food_row.get('allergens_en')     or 'No allergen information available',
            'allergy_warnings': FoodDBService.check_allergens(food_row, profile),
            'source':          'database',   # internal flag, not shown in UI
        }
        return product_data

    @staticmethod
    def cache_food(barcode: str, product_data: dict) -> None:
        """
        Saves a dynamically resolved product into the local SQLite database.
        Allows instant offline hits for this barcode on all subsequent scans.
        """
        conn = _get_conn()
        if conn is None:
            return

        try:
            cur = conn.cursor()
            cur.execute("""
                INSERT OR REPLACE INTO foods (
                    code, product_name, brands, calories_kcal, fat_g, carbs_g, protein_g, ingredients_text, allergens_en
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                barcode.strip(),
                product_data.get('product_name', 'Packaged Food'),
                '',  # brands (empty is fine)
                product_data.get('calories'),
                product_data.get('fat_g'),
                product_data.get('carbs_g'),
                product_data.get('protein_g'),
                product_data.get('ingredients', ''),
                product_data.get('allergens', '')
            ))
            conn.commit()
        except Exception:
            # Silence DB write exceptions in request lifecycle so api still responds
            pass

