import base64
import json
import re
from google.genai import types
from app.core.config import settings
from app.schemas.meal import MealScanResponse
from app.services.gemini_pool import gemini_pool

class GeminiService:
    @staticmethod
    def _parse_gemini_json(raw_text: str) -> dict:
        cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw_text.strip())
        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            raise RuntimeError("Model returned malformed JSON")

    @staticmethod
    def scan_meal(image_bytes: bytes, mime_type: str, profile: dict = None) -> dict:
        profile_context = ""
        if profile:
            conditions = profile.get('medical_conditions', [])
            restrictions = profile.get('dietary_restrictions', [])
            allergies = profile.get('allergies', [])
            goal = profile.get('goal', '')
            profile_context = f"""
            User's Health Profile & Clinical Constraints:
            - Goal: {goal or 'General Health'}
            - Medical Conditions: {', '.join(conditions) if conditions else 'None'}
            - Dietary Restrictions: {', '.join(restrictions) if restrictions else 'None'}
            - Known Allergies: {', '.join(allergies) if allergies else 'None'}

            CLINICAL & GOAL SAFETY EVALUATION RULES:
            1. Diabetes / High Blood Sugar: If meal contains high carbs (> 45g) or refined/added sugars/sweetened desserts, add a specific warning in 'health_warnings' and suggest a lower-GI alternative in 'suggestions'.
            2. Hypertension / High Blood Pressure: If meal appears high in sodium (pickles, papad, instant noodles, cured meats, heavily salted/MSG dishes), add a warning in 'health_warnings'.
            3. IBS / Digestive Issues: If meal is high in fat (> 15g-20g, deep fried dishes, heavy creams/ghee), contains artificial polyol sweeteners, excessive hot chili spice, or heavy lactose, add a warning in 'health_warnings' and suggest a gut-friendly alternative in 'suggestions'.
            4. Fat Loss / Weight Loss Goal: If meal is very calorie-dense (> 750 kcal) or loaded with saturated fats/oils, mention a portion/cooking swap in 'suggestions'.
            5. Muscle Gain / Bulk Goal: If meal is low in protein (< 15g), suggest adding a lean protein source in 'suggestions'.
            6. Allergies / Restrictions: Immediately flag any conflict with known allergies or dietary restrictions in 'health_warnings'.
            """

        system_instruction = f"""
        You are a precise food, meal image recognition, and clinical nutrition system.
        Look directly at the visual elements in the photograph and identify the authentic name of the dish shown.
        Base your recognition strictly on the actual food visible in the image.
        If the image does not contain food, or you cannot identify any food item with reasonable confidence, set is_food to false and leave nutrition fields empty/0.
        Otherwise, set is_food to true and provide an accurate estimate of portion sizes in grams and macronutrients.
        Set recognition_confidence to 'high' if the image is clear and identifiable, or 'low' if blurry or unclear.
        {profile_context}
        """

        prompt = "Analyze the food shown in this image and return the complete nutritional breakdown according to the schema."
        
        response = gemini_pool.generate_content(
            model='gemini-3.6-flash',
            contents=[
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type=mime_type
                ),
                prompt
            ],
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                temperature=0.0,
                response_mime_type="application/json",
                response_schema=MealScanResponse,
            ),
            require_vision=True
        )
        
        try:
            return GeminiService._parse_gemini_json(response.text)
        except Exception as e:
            raise RuntimeError(f"Failed to parse meal scan results. Please try again. Detailed error: {str(e)}")

    @staticmethod
    def evaluate_ingredients(
        ingredients: str,
        allergens: str,
        profile: dict = None,
        macros: dict = None,
    ) -> list[str]:
        """
        Uses Gemini AI to evaluate a product's ingredients, allergens, and macros
        against the user's health profile and medical conditions.
        Supports both ingredient-based AND macro-based clinical triggers
        (e.g., high carbs for Diabetes, high fat for Diarrhoea/Pancreatitis).
        """
        if not profile:
            return []

        conditions_str = ', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'
        restrictions_str = ', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'
        allergies_str = ', '.join(profile.get('allergies', [])) if profile.get('allergies') else 'None'

        macro_context = ""
        if macros:
            macro_context = f"""
        Nutritional Values Per Serving:
        - Calories: {macros.get('calories', 'Unknown')} kcal
        - Carbohydrates: {macros.get('carbs_g', 'Unknown')} g
        - Fat: {macros.get('fat_g', 'Unknown')} g
        - Protein: {macros.get('protein_g', 'Unknown')} g
        """

        carbs_val = macros.get('carbs_g', '?') if macros else '?'
        fat_val = macros.get('fat_g', '?') if macros else '?'

        prompt = f"""You are an expert clinical nutritionist and medical safety evaluator.

The user has scanned a packaged food product with the following details:
Ingredients: {ingredients or 'Not specified'}
Listed Allergens: {allergens or 'Not specified'}
{macro_context}
The user's health profile:
- Medical Conditions: {conditions_str}
- Known Allergies: {allergies_str}
- Dietary Restrictions: {restrictions_str}

Task:
Analyze ALL of the above — ingredients, allergens, AND nutritional values — against the user's health profile.
Use your full medical and nutritional knowledge to identify ANY conflicts. The examples below are illustrative, NOT exhaustive — apply clinical reasoning for ALL conditions the user has listed, even if they are not mentioned below.

Clinical rules to apply (examples only):
- Diabetes / High Blood Sugar: Warn if carbs > 45g per serving, or if ingredients contain added sugars (sugar, glucose, fructose, corn syrup, dextrose, honey, maltose, caramel).
- Diarrhoea / IBS / Digestive Issues: Warn if fat > 15g per serving, or if product contains artificial sweeteners (sorbitol, mannitol, xylitol), high-fibre grains, spicy ingredients, lactose, or excessive caffeine.
- Hypertension / High Blood Pressure: Warn if product contains salt, sodium, MSG, or soy sauce in significant quantities.
- Celiac Disease / Gluten Intolerance: Warn if ingredients contain wheat, gluten, barley, rye, or malt.
- Lactose Intolerance: Warn if ingredients contain milk, lactose, cream, cheese, whey, or butter.
- Kidney Disease / Renal Failure: Warn if product is high in potassium, phosphorus, or sodium.
- Heart Disease: Warn if product contains trans fats, saturated fats > 10g, or high sodium.
- Peanut / Nut Allergy: Warn if allergens or ingredients mention peanuts, groundnuts, tree nuts, almonds, cashews, walnuts, hazelnuts.
- Gout: Warn if product is high in purines (organ meats, shellfish, red meat extracts, yeast extract, beer).
- PCOS / Insulin Resistance: Warn if product is high in refined carbs, added sugars, or trans fats.
- Thyroid / Hypothyroidism: Warn if product contains raw cruciferous vegetables (broccoli, kale, soy) that can affect iodine uptake.
- Any other condition the user has listed: Use your medical knowledge to determine if this product is safe or harmful.

If there are NO conflicts, return an empty list [].

Return ONLY a JSON array of warning strings. Be specific and mention actual values. Examples:
["WARNING: High in carbohydrates ({carbs_val}g) — may spike blood sugar levels. Portion control is recommended for managing Diabetes / High Blood Sugar."]
["CRITICAL: This product contains peanuts which conflicts with your Peanut Allergy!"]
["WARNING: High fat content ({fat_val}g) — high-fat foods can worsen Diarrhoea and digestive discomfort."]
[]
"""
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            return json.loads(response.text)
        except Exception:
            return []

    @staticmethod
    def estimate_food_macros(query: str) -> dict:
        prompt = f"""
        You are an expert clinical dietitian and nutritional database engine with comprehensive grounding in the USDA Food Data Central and South Asian / Pakistani / Middle Eastern culinary databases (including Ramadan foods like Sehri/Iftar items: Paratha, Roti, Daal, Biryani, Nihari, Haleem, Chana Chaat, Pakoras, Jalebi, Chai, Lassi, Rooh Afza, Khajoor/Dates, Omelette, Fruits).
        
        The user wants to log the following meal/food item: "{query}".
        
        Task:
        1. FIRST, determine if the input is a recognizable food or meal. If it is random gibberish, nonsense text, non-food objects, or anything that is NOT an edible food/drink/meal, set "is_food" to false.
        2. If it IS a valid food/meal:
           a. Parse all items and quantities mentioned (e.g., "2 Aloo Parathas and 1 Chai").
           b. Calculate the combined total nutritional values across all items in the meal description.
           c. If quantity is not specified, assume 1 standard adult serving.
        
        Return ONLY a valid JSON object with the following exact keys:
        - "is_food": Boolean (true if the input is a recognizable food/drink/meal, false if it is gibberish, random text, or non-food)
        - "name": Standardized, appetizing name of the meal (e.g., "Aloo Parathas (2) with Milk Tea"). Use empty string "" if is_food is false.
        - "calories": Integer (total calories in kcal). Use 0 if is_food is false.
        - "protein_g": Float (total protein in grams, rounded to 1 decimal place). Use 0 if is_food is false.
        - "carbs_g": Float (total carbohydrates in grams, rounded to 1 decimal place). Use 0 if is_food is false.
        - "fat_g": Float (total fat in grams, rounded to 1 decimal place). Use 0 if is_food is false.
        """
        
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            data = json.loads(response.text)
            
            # Check if AI recognized it as food
            is_food = data.get("is_food", True)
            if not is_food:
                return {
                    "is_food": False,
                    "name": "",
                    "calories": 0,
                    "protein_g": 0.0,
                    "carbs_g": 0.0,
                    "fat_g": 0.0,
                }
            
            return {
                "is_food": True,
                "name": data.get("name", query.title()),
                "calories": int(data.get("calories", 0)),
                "protein_g": float(data.get("protein_g", 0.0)),
                "carbs_g": float(data.get("carbs_g", 0.0)),
                "fat_g": float(data.get("fat_g", 0.0)),
            }
        except Exception as e:
            # Re-raise so the caller/API knows Gemini estimation failed
            # rather than silently fabricating hardcoded nutrition data.
            raise RuntimeError(f"Gemini macro estimation failed for '{query}': {str(e)}")

    @staticmethod
    def fill_macros_and_evaluate(
        product_name: str,
        ingredients: str = "",
        allergens: str = "",
        profile: dict = None
    ) -> dict:
        """
        Single combined Gemini AI call that:
        1. Estimates accurate standard macros (calories, protein, carbs, fat) for product_name
        2. Evaluates allergies and clinical health warnings against user's profile
        This prevents doing 2 serial Gemini calls (Fix 7).
        """
        conditions_str = ', '.join(profile.get('medical_conditions', [])) if profile and profile.get('medical_conditions') else 'None'
        restrictions_str = ', '.join(profile.get('dietary_restrictions', [])) if profile and profile.get('dietary_restrictions') else 'None'
        allergies_str = ', '.join(profile.get('allergies', [])) if profile and profile.get('allergies') else 'None'

        prompt = f"""You are an expert clinical nutritionist and food database.
The user has scanned a food product with missing nutritional breakdown:
Product: {product_name}
Known Ingredients: {ingredients or 'Standard ingredients for this product'}
Known Allergens: {allergens or 'Not specified'}

User's Health Profile:
- Medical Conditions: {conditions_str}
- Known Allergies: {allergies_str}
- Dietary Restrictions: {restrictions_str}

Tasks:
1. Estimate accurate nutritional values per standard serving/100g (Calories kcal, Protein g, Carbs g, Fat g).
2. Apply clinical dietary rules against the calculated nutritional values and ingredients (e.g. Diabetes: warn if carbs > 45g or added sugar; Diarrhoea: warn if fat > 15g, artificial sweeteners, or lactose; Hypertension: sodium; Celiac: gluten; Allergies: peanuts, dairy, tree nuts).
3. If conflicts exist, list specific clinical warnings in allergy_warnings array. If safe, return empty array [].

Return ONLY a valid JSON object with exact keys:
- "calories": Integer (kcal)
- "protein_g": Float
- "carbs_g": Float
- "fat_g": Float
- "ingredients": String
- "allergens": String
- "allergy_warnings": Array of strings
"""
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            result = json.loads(response.text)
            return {
                "calories":         int(result.get("calories", 0)),
                "protein_g":        float(result.get("protein_g", 0.0)),
                "carbs_g":          float(result.get("carbs_g", 0.0)),
                "fat_g":            float(result.get("fat_g", 0.0)),
                "ingredients":      result.get("ingredients", ingredients or "Standard ingredients"),
                "allergens":        result.get("allergens", allergens or "No major allergens"),
                "allergy_warnings": result.get("allergy_warnings", [])
            }
        except Exception:
            return {}

    @staticmethod
    def identify_barcode_food(barcode: str, profile: dict = None) -> dict:

        allergies_str = ', '.join(profile.get('allergies', [])) if profile and profile.get('allergies') else 'None'
        conditions_str = ', '.join(profile.get('medical_conditions', [])) if profile and profile.get('medical_conditions') else 'None'
        
        prompt = f"""
        You are an advanced AI food intelligence system with comprehensive knowledge of global food products, barcodes (EAN-13, UPC, GTIN), packaged groceries, snacks, beverages, and regional brands (including International and South Asian/Pakistani products like Shan, National, Olper's, Mitchell's, Dawn, Tapal, Peak Freans, Lipton, Nestlé, Ferrero, Mars, Mondelez).

        The user scanned or entered the following product barcode: "{barcode}".

        Tasks:
        1. Identify the exact food or beverage product corresponding to this barcode (for example, 3017620422003 is Nutella Hazelnut Spread, 5000159461122 is Snickers Bar, 7622210449283 is Oreo Cookies, 5449000000996 is Coca-Cola, 7613035799982 is KitKat, 9002490100070 is Red Bull, etc.). If the barcode is less common or custom, identify the most likely packaged food item.
        2. Calculate standard nutritional breakdown: Calories (kcal), Protein (g), Carbs (g), Fat (g).
        3. List standard ingredients and allergen notes.
        4. Cross-check against user's health profile:
           - User Allergies: {allergies_str}
           - Medical Conditions: {conditions_str}
           If any ingredient conflicts with their health profile, generate clinical warning bullet points.

        Return ONLY a valid JSON object with the following exact keys:
        - "product_name": String (e.g., "Nutella Hazelnut Spread")
        - "calories": Integer (e.g., 539)
        - "protein_g": Float (e.g., 6.3)
        - "carbs_g": Float (e.g., 57.5)
        - "fat_g": Float (e.g., 30.9)
        - "ingredients": String (e.g., "Sugar, palm oil, hazelnuts (13%), skimmed milk powder, low-fat cocoa, soy lecithin, vanillin")
        - "allergens": String (e.g., "Tree Nuts (Hazelnuts), Milk, Soy")
        - "allergy_warnings": Array of strings (e.g., ["Contains tree nuts (hazelnuts)", "Contains milk/dairy"])
        """
        
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.1,
                ),
            )
            result = json.loads(response.text)
            return {
                "product_name": result.get("product_name", f"Food Item ({barcode})"),
                "calories": int(result.get("calories", 250)),
                "protein_g": float(result.get("protein_g", 5.0)),
                "carbs_g": float(result.get("carbs_g", 30.0)),
                "fat_g": float(result.get("fat_g", 10.0)),
                "ingredients": result.get("ingredients", "Standard food ingredients"),
                "allergens": result.get("allergens", "No major allergens identified"),
                "allergy_warnings": result.get("allergy_warnings", [])
            }
        except Exception as e:
            # Re-raise so the GeminiPool key rotation can handle 429s,
            # and so callers can surface a proper error to the user
            # instead of returning silent dummy/phantom nutrition data.
            raise


    @staticmethod
    def generate_coaching_summary(score: float, profile: dict = None, language: str = "en") -> str:
        profile_context = ""
        if profile:
            profile_context = f"""
            The user's health profile:
            - Goal: {profile.get('goal', 'N/A')}
            - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
            """
            
        prompt = f"""
        You are an AI nutrition coach. The user has a 30-day habit score of {score:.1f}/100.
        {profile_context}
        
        Write a short, personalized, encouraging one-paragraph coaching message (max 3 sentences) 
        reflecting on their score and giving one piece of actionable advice tailored to their profile.
        """
        if language == "ur":
            prompt += "\nMANDATORY: You must respond entirely in Urdu language using correct Arabic-script spelling and grammar."

        try:
            response = gemini_pool.generate_content(
                model='gemini-3.5-flash-lite',
                contents=[prompt],
            )
            return response.text.strip()
        except Exception:
            if language == "ur":
                if score >= 80:
                    return "بہت عمدہ کام! آپ کا تسلسل رنگ لا رہا ہے۔ اسی طرح محنت جاری رکھیں!"
                elif score >= 50:
                    return "آپ اچھی پیش رفت کر رہے ہیں۔ اپنے میکرو اہداف پر تھوڑا اور تسلسل برقرار رکھنے سے آپ کا اسکور مزید بہتر ہو جائے گا!"
                else:
                    return "اپنے کھانے کا ریکارڈ لکھتے رہیں! آپ کے عادات کے اسکور کو بہتر بنانے کے لیے تسلسل سب سے اہم ہے۔"
            else:
                if score >= 80:
                    return "Fantastic job! Your consistency is paying off. Keep up the great work!"
                elif score >= 50:
                    return "You're making good progress. A little more consistency with your macro targets will boost your score!"
                else:
                    return "Keep logging your meals! Consistency is key to improving your habit score."

    @staticmethod
    def generate_food_swaps(recent_meals: list[str], profile: dict = None, language: str = "en") -> dict:
        profile_context = ""
        if profile:
            conditions = profile.get('medical_conditions', [])
            restrictions = profile.get('dietary_restrictions', [])
            goal = profile.get('goal', 'General Health')
            profile_context = f"""
            The user's health profile:
            - Goal: {goal}
            - Medical Conditions: {', '.join(conditions) if conditions else 'None'}
            - Dietary Restrictions: {', '.join(restrictions) if restrictions else 'None'}
            """
            
        prompt = f"""
        You are an expert clinical nutritionist and culinary dietitian. 
        The user has logged the following meal item(s) today:
        {json.dumps(recent_meals)}
        
        {profile_context}
        
        MANDATORY CLINICAL & CULINARY RULES:
        1. HEALTHY MEAL GATEKEEPER & INHERENTLY HEALTHY WHOLE FOODS:
           - First, evaluate if the logged food item(s) are inherently nutritious whole foods or balanced meals (e.g. Avocado, eggs, lentils/daal, chicken breast, fish/salmon, oats, unsweetened yogurt, vegetables, salads, quinoa, nuts, seeds, fresh fruit like berries/apples/guava).
           - INHERENTLY HEALTHY FOODS MUST NEVER BE SWAPPED AWAY:
             If an item is fundamentally healthy and nutrient-dense (such as avocados, boiled eggs, almonds, Greek yogurt, or grilled chicken):
             DO NOT swap it for another food!
           - PORTION & QUANTITY HANDLING (CRITICAL):
             If the user logged a healthy food in a larger quantity (e.g. "2 avocados", "handful of almonds", "3 eggs", "large bowl of oats") or did not specify an exact quantity:
             * DO NOT swap the meal! Set "is_healthy": true and "swaps": [].
             * Instead, use the "message" field to praise their choice and provide a helpful, practical portion guidance tip (e.g. "Great choice! Avocados provide heart-healthy fats and fiber that stabilize blood sugar. Pro tip: Since they are calorie-dense, 1/2 to 1 avocado per day is the optimal serving size for your goals.").
           - If ALL the logged meal(s) are healthy, balanced, or inherently nutritious, set "is_healthy": true and "swaps": []. DO NOT force or invent a swap!

        2. UNHEALTHY MEALS & SWAP GENERATION (RESERVED FOR TRULY UNHEALTHY / HIGH-RISK FOODS):
           - Only trigger swaps for items that are genuinely unhealthy, processed, high-glycemic, or deeply fried:
             * Deep-fried items (e.g. samosa, pakora, french fries, crispy fried chicken, paratha).
             * Refined sugars & syrups (e.g. gulab jamun, jalebi, soda/cola, donuts, pastries, ice cream, sweetened energy drinks).
             * Refined high-GI carbs (e.g. white flour naan, halwa puri, white bread with sugary jam).
             * Heavy saturated fat / oil floating dishes (e.g. oily beef nihari, deep oily restaurant karahi).
             * High-sodium processed meats / snacks (e.g. cured sausages, salty chips, instant noodles).
           - In these genuinely unhealthy cases:
             - Set "is_healthy": false.
             - Generate a practical, cuisine-matched healthier swap for EVERY unique unhealthy meal in the list.
             - If there are multiple unhealthy meals (e.g. 4 meals logged today), provide a swap for EACH ONE in the "swaps" list. Do NOT cap at 3. Do NOT omit or combine items.

        3. CUISINE-MATCHING MANDATE (CRITICAL):
           - The recommended swap MUST strictly match the cuisine, culture, and culinary style of the original food:
             * PAKISTANI / SOUTH ASIAN DISHES (e.g. Biryani, Nihari, Halwa Puri, Paratha, Samosa, Pakora, Karahi, Haleem, Kheer, Mithai, Jalebi):
               Swap ONLY for a healthy, authentic Pakistani alternative.
               Examples:
               - Oily/Fried Paratha -> Whole-wheat phulka roti with boiled egg or daal.
               - Deep-fried Samosa / Pakora -> Roasted spiced chana (chickpeas) or baked spiced vegetable cutlet.
               - Oily Beef Nihari / Heavy Karahi -> Murgh Yakhni (lean spiced chicken broth) or grilled chicken tikka with mint raita.
               - White Rice Biryani -> High-protein chicken brown basmati pulao with cucumber raita or Daal Chawal (high daal ratio) with salad.
               - Gulab Jamun / Jalebi -> Fresh guava/papaya slices with chaat masala or low-fat spiced kheer with stevia.
             * WESTERN DISHES (e.g. Cheeseburger, Pepperoni Pizza, French Fries, Donut, Soda, Fried Chicken):
               Swap ONLY for a healthy Western alternative.
               Examples:
               - Double Cheeseburger / Fast food burger -> Whole-wheat grilled chicken wrap or turkey breast on lettuce bun with sweet potato wedges.
               - Pepperoni Pizza -> Thin-crust whole-wheat pita pizza with roasted vegetables and lean protein.
               - French Fries -> Air-fried zucchini or sweet potato wedges.
               - Sugary Donut / Pastry -> Greek yogurt with mixed berries and a touch of honey.
               - Sugary Soda -> Sparkling lemon water or iced berry infusion.

        4. MEDICAL CONDITIONS GUARDRAILS:
           - Diabetes / High Blood Sugar: Prevent glycemic spikes (replace refined carbs/sugar with low-GI, high-fiber, lean protein).
           - Hypertension / High Blood Pressure: Slash sodium (replace processed/cured meats, salty pickles/chips with herb-seasoned, potassium-rich foods).
           - IBS / Digestion: Avoid deep-fried, heavy cream, extremely spicy, or high-FODMAP triggers.
           - Fat Loss: Substantially reduce caloric density and oil while preserving satiety (save 150-300 kcal).
           - Muscle Gain: Boost lean protein and quality complex carbs.

        if an item is good for the user and user hasn't explicitely tell about the quantity of that health product don't recommend swap instead we aim to show a message of the optimal quantity of the product to use.
        Return ONLY a JSON object with this exact schema:
        {{
          "is_healthy": boolean,
          "message": string,
          "swaps": [
            {{
              "original_food": string,
              "healthy_swap": string,
              "reason": string
            }}
          ]
        }}
        """
        if language == "ur":
            prompt += "\nMANDATORY: Write the values for 'message', 'original_food', 'healthy_swap', and 'reason' in Urdu language (using Urdu Arabic script)."

        try:
            response = gemini_pool.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                ),
            )
            parsed = GeminiService._parse_gemini_json(response.text)
            if isinstance(parsed, dict):
                swaps_list = parsed.get("swaps", [])
                if not isinstance(swaps_list, list):
                    swaps_list = []
                is_healthy = parsed.get("is_healthy", len(swaps_list) == 0)
                return {
                    "is_healthy": bool(is_healthy),
                    "message": str(parsed.get("message", "")),
                    "swaps": swaps_list
                }
            elif isinstance(parsed, list):
                return {
                    "is_healthy": len(parsed) == 0,
                    "message": "",
                    "swaps": parsed
                }
            return {"is_healthy": True, "message": "Meal logged successfully.", "swaps": []}
        except Exception as e:
            logger.error(f"Error in generate_food_swaps: {e}")
            return {"is_healthy": True, "message": "Meal logged successfully.", "swaps": []}

    @staticmethod
    def generate_grocery_list(recent_meals: list[str], profile: dict = None) -> list[dict]:
        profile_context = ""
        if profile:
            profile_context = f"""
            User's health profile:
            - Goal: {profile.get('goal', 'N/A')}
            - Medical Conditions: {', '.join(profile.get('medical_conditions', [])) if profile.get('medical_conditions') else 'None'}
            - Dietary Restrictions: {', '.join(profile.get('dietary_restrictions', [])) if profile.get('dietary_restrictions') else 'None'}
            """
            
        prompt = f"""
        You are an expert nutritionist. Generate a weekly grocery list for a user.
        {profile_context}
        
        User's recent logged meals are:
        {json.dumps(recent_meals)}
        
        Generate a smart grocery list of raw ingredients and healthy foods they need to buy for the upcoming week to prepare balanced meals aligned with their goal and health profile. Avoid ingredients that conflict with their dietary restrictions or medical conditions.
        
        Return ONLY a JSON array of category objects, where each object has the keys:
        - "category": string (e.g., "Produce", "Proteins", "Dairy & Alternatives", "Grains & Pantry", "Healthy Snacks")
        - "items": list of objects, each containing:
            - "name": string (the item name, e.g. "Spinach", "Avocado", "Chicken breast")
            - "quantity": string (e.g. "250g", "6 units", "1 kg")
            - "checked": boolean (always false)
        """
        try:
            response = gemini_pool.generate_content(
                model='gemini-3.6-flash',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                ),
            )
            return json.loads(response.text)
        except Exception:
            return [
                {
                    "category": "Produce",
                    "items": [
                        {"name": "Spinach", "quantity": "1 bunch", "checked": False},
                        {"name": "Bananas", "quantity": "1 dozen", "checked": False}
                    ]
                },
                {
                    "category": "Proteins",
                    "items": [
                        {"name": "Chicken Breast", "quantity": "1 kg", "checked": False},
                        {"name": "Eggs", "quantity": "1 dozen", "checked": False}
                    ]
                }
            ]
