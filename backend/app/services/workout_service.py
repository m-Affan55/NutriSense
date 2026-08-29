import json
import logging
from typing import Dict, Any, List
from google.genai import types
from app.schemas.workout import WorkoutPlanResponse, WorkoutDay, Exercise
from app.services.gemini_pool import gemini_pool

logger = logging.getLogger("workout_service")

class WorkoutService:
    @staticmethod
    def generate_workout_plan(profile: Dict[str, Any], is_ramadan: bool = False, language: str = "en") -> Dict[str, Any]:
        """
        Generates an AI-customized 7-day workout plan based on the user's clinical profile,
        fitness goal, activity level, and medical conditions.
        """
        age = profile.get("age", 25)
        gender = profile.get("gender", "male")
        weight_kg = profile.get("weight_kg", 70.0)
        height_cm = profile.get("height_cm", 175.0)
        goal = str(profile.get("goal", "maintain")).lower()
        activity_level = str(profile.get("activity_level", "sedentary")).lower()
        medical_conditions = profile.get("medical_conditions", [])
        
        conditions_str = ", ".join(medical_conditions) if medical_conditions else "None (Healthy individual)"
        
        # Calculate BMI
        height_m = height_cm / 100.0 if height_cm > 0 else 1.75
        bmi = round(weight_kg / (height_m * height_m), 1) if height_m > 0 else 22.5
        
        # Construct Clinical Prompt
        system_instruction = f"""
        You are the Chief Clinical Exercise Physiologist and AI Fitness Director at NutriSense.
        Your job is to generate a comprehensive, highly personalized, clinical-grade 7-day weekly workout schedule 
        (Monday through Sunday) tailored specifically to the user's health profile, physical biometrics, and medical conditions.

        User Physical Profile:
        - Age: {age} years | Gender: {gender}
        - Weight: {weight_kg} kg | Height: {height_cm} cm | BMI: {bmi}
        - Primary Fitness Goal: {goal} (e.g. fat_loss, muscle_gain, maintain)
        - Activity Level: {activity_level}
        - Medical Conditions: {conditions_str}
        - Fasting / Ramadan Mode: {"YES (Ramadan Fasting Active)" if is_ramadan else "NO (Standard Schedule)"}

        MANDATORY CLINICAL SAFETY GUIDELINES:
        1. DIABETES / BLOOD GLUCOSE:
           - Emphasize combination of moderate resistance training and low-impact steady aerobic exercise to activate GLUT4 glucose transporters and improve insulin sensitivity.
           - Emphasize post-meal workout timing (30-60 mins after a meal) to blunt postprandial glucose spikes.
           - Provide clinical safety notes: Hydrate adequately, avoid prolonged exhaustive fasted exercise, and keep fast-acting glucose accessible.

        2. HYPERTENSION / HIGH BLOOD PRESSURE:
           - Emphasize rhythmic dynamic aerobic exercises and moderate-resistance circuits with continuous breathing.
           - STRICTLY FORBID Valsalva maneuvers (holding breath during heavy exertion) and prolonged heavy isometric contractions.
           - Include extended 5-8 minute dynamic warm-up and gradual cool-down to prevent sudden blood pressure fluctuations.

        3. JOINT PAIN / ARTHRITIS / KNEE ISSUES:
           - Recommend low-impact, non-compressive exercises (glute bridges, seated rows, resistance bands, bodyweight isometric holds, wall sits, walking).
           - STRICTLY AVOID high-impact plyometrics, jump squats, and heavy compressive loading.

        4. GOAL SPECIFICITY:
           - FAT LOSS / WEIGHT REDUCTION (Overweight / High BMI): High-density metabolic conditioning, Zone 2 steady-state cardio, compound functional bodyweight/resistance training.
           - MUSCLE GAIN / HYPERTROPHY (Skinny / Low Muscle Mass): Structured progressive overload (Push/Pull/Legs or Upper/Lower), 8-12 rep hypertrophy ranges, 3-4 sets, adequate rest intervals.
           - GENERAL HEALTH & MAINTENANCE: Balanced functional movement, mobility, core stabilization, and cardiovascular endurance.

        5. REST DAYS & RECOVERY:
           - Schedule 2 to 3 Rest / Active Recovery days per week (e.g., Wednesday and Sunday as Rest Days).
           - On rest days, set is_rest_day=True, duration_mins=0, empty exercises list, and provide restorative recovery guidance in cool_down and clinical_safety_notes.

        6. RAMADAN FASTING CONSIDERATIONS:
           - If Ramadan mode is active: Schedule sessions either 30-45 minutes before Iftar (light-to-moderate cardio/mobility) or 1.5 to 2 hours post-Iftar (resistance training), ensuring hydration during the non-fasting window.

        Return ONLY a JSON response strictly conforming to the WorkoutPlanResponse schema.
        """
        if language == "ur":
            system_instruction += """
            MANDATORY LANGUAGE TRANSLATION DIRECTIVE:
            You MUST translate and write ALL user-facing text fields in the final JSON response ENTIRELY in URDU language using correct Arabic-script spelling (e.g. use Urdu text for plan_name, goal_summary, weekly_frequency, medical_considerations, workout_title, target_focus, warm_up, cool_down, clinical_safety_notes, exercise name, target_muscle, reps, form_cues, and precautions).
            For example:
            - Keep day_name in English (Monday, Tuesday, etc. so the app can parse it correctly).
            - Write all exercise names, muscles, precautions, and instructions in Urdu Arabic script.
            """

        prompt = f"Generate the complete 7-day personalized workout plan for this {goal} user with {conditions_str}."

        try:
            response = gemini_pool.generate_content(
                model="gemini-3.6-flash",
                contents=[prompt],
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    temperature=0.2,
                    response_mime_type="application/json",
                    response_schema=WorkoutPlanResponse,
                ),
            )
            data = json.loads(response.text)
            return data
        except Exception as e:
            logger.warning(f"AI workout generation encountered error: {e}. Utilizing clinical fallback engine.")
            return WorkoutService._generate_clinical_fallback(profile, is_ramadan, language)

    @staticmethod
    def _generate_clinical_fallback(profile: Dict[str, Any], is_ramadan: bool = False, language: str = "en") -> Dict[str, Any]:
        """
        Deterministic, clinically safe fallback workout plan generator if AI is offline or rate-limited.
        """
        goal = str(profile.get("goal", "maintain")).lower()
        conditions = profile.get("medical_conditions", [])
        is_diabetic = any("diabet" in str(c).lower() for c in conditions)
        is_hypertensive = any("hypertens" in str(c).lower() or "blood pressure" in str(c).lower() for c in conditions)
        has_joint_pain = any("joint" in str(c).lower() or "arthrit" in str(c).lower() or "knee" in str(c).lower() for c in conditions)

        if "muscle" in goal:
            plan_name = "Progressive Hypertrophy & Strength Split"
            goal_summary = "Structured progressive overload resistance training to maximize lean muscle building and metabolic health."
            ex1 = [
                Exercise(name="Dumbbell/Bodyweight Push-Ups", target_muscle="Chest & Triceps", sets=3, reps="10-12 reps", rest_seconds=60, form_cues="Keep core tight, elbows at 45 degrees", precautions="Keep steady breathing"),
                Exercise(name="Dumbbell Overhead Shoulder Press", target_muscle="Deltoids", sets=3, reps="10-12 reps", rest_seconds=60, form_cues="Press straight up, avoid arching lower back", precautions="Use moderate weight"),
                Exercise(name="Bodyweight Tricep Dips", target_muscle="Triceps", sets=3, reps="10-15 reps", rest_seconds=45, form_cues="Control descent, push through palms", precautions="Avoid excessive shoulder extension"),
            ]
            ex2 = [
                Exercise(name="Resistance Band / Dumbbell Rows", target_muscle="Lats & Upper Back", sets=3, reps="12 reps", rest_seconds=60, form_cues="Squeeze shoulder blades at top", precautions="Hinge at hips with flat back"),
                Exercise(name="Bicep Curls", target_muscle="Biceps", sets=3, reps="12-15 reps", rest_seconds=45, form_cues="Keep elbows pinned to sides", precautions="No swinging"),
                Exercise(name="Plank Hold", target_muscle="Core", sets=3, reps="45 seconds", rest_seconds=45, form_cues="Straight line from head to heels", precautions="Breathe continuously"),
            ]
            ex3 = [
                Exercise(name="Bodyweight Goblet Squats", target_muscle="Quadriceps & Glutes", sets=4, reps="12-15 reps", rest_seconds=60, form_cues="Chest up, knees tracking toes", precautions="Low-impact form"),
                Exercise(name="Glute Bridges", target_muscle="Glutes & Hamstrings", sets=3, reps="15 reps", rest_seconds=45, form_cues="Drive through heels, squeeze glutes at top", precautions="Avoid hyperextending spine"),
                Exercise(name="Calf Raises", target_muscle="Calves", sets=3, reps="20 reps", rest_seconds=30, form_cues="Full stretch and contraction at top", precautions="Hold wall for balance"),
            ]
        elif "fat" in goal or "loss" in goal:
            plan_name = "Metabolic Fat-Loss & Cardiovascular Circuit"
            goal_summary = "High-efficiency metabolic conditioning combined with low-impact cardio to optimize caloric deficit and preserve lean muscle."
            ex1 = [
                Exercise(name="Bodyweight Air Squats", target_muscle="Quads & Glutes", sets=3, reps="15 reps", rest_seconds=45, form_cues="Chest up, drive through heels", precautions="Keep steady pace"),
                Exercise(name="Incline Push-Ups / Wall Push-Ups", target_muscle="Chest & Arms", sets=3, reps="12 reps", rest_seconds=45, form_cues="Core engaged", precautions="Exhale on push"),
                Exercise(name="Brisk Walking / Step-Ups", target_muscle="Cardio Endurance", sets=3, reps="2 mins", rest_seconds=30, form_cues="Pump arms lightly", precautions="Maintain steady rhythm"),
            ]
            ex2 = [
                Exercise(name="Resistance Band Rows", target_muscle="Back & Posture", sets=3, reps="15 reps", rest_seconds=45, form_cues="Draw elbows back smoothly", precautions="Keep shoulders down"),
                Exercise(name="Standing Knee-to-Elbow Marches", target_muscle="Core & Cardio", sets=3, reps="20 reps", rest_seconds=30, form_cues="Engage abs with each knee raise", precautions="Low-impact continuous movement"),
                Exercise(name="Glute Bridge Pulses", target_muscle="Glutes", sets=3, reps="20 reps", rest_seconds=30, form_cues="Squeeze glutes at top of bridge", precautions="Gentle on lower back"),
            ]
            ex3 = [
                Exercise(name="Zone-2 Aerobic Walk / Light Cycling", target_muscle="Cardiovascular System", sets=1, reps="25 mins", rest_seconds=0, form_cues="Breathe rhythmically through nose", precautions="Stay hydrated"),
                Exercise(name="Bird-Dog Holds", target_muscle="Core & Spinal Stability", sets=3, reps="10 each side", rest_seconds=30, form_cues="Reach arm and opposite leg parallel to floor", precautions="Keep pelvis level"),
            ]
        else:
            plan_name = "Balanced Functional Health & Mobility Plan"
            goal_summary = "Comprehensive balance of full-body functional strength, core stabilization, and cardiovascular wellness."
            ex1 = [
                Exercise(name="Bodyweight Squats to Chair", target_muscle="Legs & Mobility", sets=3, reps="12 reps", rest_seconds=45, form_cues="Sit back gently to chair and stand", precautions="Knees behind toes"),
                Exercise(name="Doorway Row / Band Pull-Apart", target_muscle="Upper Back", sets=3, reps="15 reps", rest_seconds=45, form_cues="Squeeze shoulder blades", precautions="Gentle posture alignment"),
                Exercise(name="Standing Calf Raises", target_muscle="Lower Legs", sets=3, reps="15 reps", rest_seconds=30, form_cues="Hold for 1 sec at top", precautions="Use wall for balance"),
            ]
            ex2 = [
                Exercise(name="Brisk Walking / Low-Impact Cardio", target_muscle="Heart & Lungs", sets=1, reps="20 mins", rest_seconds=0, form_cues="Maintain conversational pace", precautions="Stay hydrated"),
                Exercise(name="Dead Bug Core Engagement", target_muscle="Deep Abdominals", sets=3, reps="10 each side", rest_seconds=45, form_cues="Press lower back flat into floor", precautions="Breathe steadily"),
            ]
            ex3 = [
                Exercise(name="Glute Bridges", target_muscle="Hips & Glutes", sets=3, reps="12 reps", rest_seconds=45, form_cues="Drive through heels", precautions="Avoid arching lower back"),
                Exercise(name="Wall Angels", target_muscle="Shoulder Mobility", sets=3, reps="10 reps", rest_seconds=30, form_cues="Slide arms along wall smoothly", precautions="Gentle range of motion"),
            ]

        # Clinical Safety Customizations
        med_notes = []
        if is_diabetic:
            med_notes.append("Diabetic Guideline: Best performed 30-45 mins after meals to optimize glucose uptake. Keep hydration high and avoid extreme fasting exertion.")
        if is_hypertensive:
            med_notes.append("Hypertension Guideline: Maintain continuous steady breathing on all repetitions. Strictly avoid holding your breath (Valsalva maneuver).")
        if has_joint_pain:
            med_notes.append("Joint Health: All exercises are low-impact and joint-sparing. If you feel any sharp joint discomfort, reduce range of motion.")
        if not med_notes:
            med_notes.append("General Health: Hydrate before, during, and after exercise. Listen to your body and rest when needed.")

        schedule = [
            WorkoutDay(
                day_name="Monday",
                is_rest_day=False,
                workout_title=f"{plan_name} - Day 1",
                target_focus="Upper Body & Core Activation",
                duration_mins=35,
                estimated_calories_burned=180,
                warm_up="5 mins dynamic arm circles, shoulder rolls, and torso twists.",
                exercises=ex1,
                cool_down="5 mins chest opening stretch, overhead lat stretch, and deep diaphragmatic breathing.",
                clinical_safety_notes=med_notes[0]
            ),
            WorkoutDay(
                day_name="Tuesday",
                is_rest_day=False,
                workout_title=f"{plan_name} - Day 2",
                target_focus="Lower Body & Posture",
                duration_mins=35,
                estimated_calories_burned=210,
                warm_up="5 mins leg swings, hip openers, and ankle rotations.",
                exercises=ex3 if "muscle" in goal else ex2,
                cool_down="5 mins hamstring stretch, quad stretch, and calf wall stretch.",
                clinical_safety_notes=med_notes[0]
            ),
            WorkoutDay(
                day_name="Wednesday",
                is_rest_day=True,
                workout_title="Rest & Active Recovery",
                target_focus="Muscle Repair, Hydration & Light Walk",
                duration_mins=0,
                estimated_calories_burned=0,
                warm_up="Optional: 10 mins gentle walking or leisurely stroll.",
                exercises=[],
                cool_down="10 mins full-body restorative mobility and gentle stretching.",
                clinical_safety_notes="Active recovery day: Focus on muscle replenishment, protein intake, and getting 8 hours of quality sleep."
            ),
            WorkoutDay(
                day_name="Thursday",
                is_rest_day=False,
                workout_title=f"{plan_name} - Day 3",
                target_focus="Full-Body Functional Strength",
                duration_mins=35,
                estimated_calories_burned=195,
                warm_up="5 mins marching in place, cat-cow stretches, and hip rotations.",
                exercises=ex2 if "muscle" in goal else ex1,
                cool_down="5 mins child's pose, seated forward fold, and gentle spinal twist.",
                clinical_safety_notes=med_notes[0]
            ),
            WorkoutDay(
                day_name="Friday",
                is_rest_day=False,
                workout_title=f"{plan_name} - Day 4",
                target_focus="Metabolic Endurance & Aerobic Stamina",
                duration_mins=30,
                estimated_calories_burned=175,
                warm_up="5 mins step-touches and gentle dynamic stretching.",
                exercises=ex3,
                cool_down="5 mins deep breathing and quad/hamstring cooldown stretches.",
                clinical_safety_notes=med_notes[0]
            ),
            WorkoutDay(
                day_name="Saturday",
                is_rest_day=True,
                workout_title="Rest & Active Mobility",
                target_focus="Joint Decompression & Light Mobility",
                duration_mins=0,
                estimated_calories_burned=0,
                warm_up="Optional: 15 mins relaxed outdoor walk.",
                exercises=[],
                cool_down="10 mins foam rolling or gentle yoga stretches.",
                clinical_safety_notes="Recharge day: Keep hydration optimal and focus on nutritious whole-food recovery meals."
            ),
            WorkoutDay(
                day_name="Sunday",
                is_rest_day=True,
                workout_title="Full Body Rest & Regeneration",
                target_focus="Weekly Reset & Mental Well-being",
                duration_mins=0,
                estimated_calories_burned=0,
                warm_up="",
                exercises=[],
                cool_down="Deep relaxation and preparation for the upcoming week.",
                clinical_safety_notes="Complete rest day to allow muscle protein synthesis and systemic nervous recovery."
            )
        ]

        if language == "ur":
            translated_plan_name = {
                "Progressive Hypertrophy & Strength Split": "عضلات بڑھانے اور طاقت کا منصوبہ",
                "Metabolic Fat-Loss & Cardiovascular Circuit": "چربی جلانے اور کارڈیو کا سرکٹ",
                "Balanced Functional Health & Mobility Plan": "فنکشنل صحت اور نقل و حرکت کا منصوبہ"
            }.get(plan_name, plan_name)
            
            translated_goal_summary = {
                "Structured progressive overload resistance training to maximize lean muscle building and metabolic health.": "عضلات بنانے اور میٹابولک صحت کو بہتر بنانے کے لیے مزاحمتی تربیت۔",
                "High-efficiency metabolic conditioning combined with low-impact cardio to optimize caloric deficit and preserve lean muscle.": "میٹابولک کنڈیشننگ اور ہلکا کارڈیو جو چربی پگھلانے اور پٹھوں کو محفوظ رکھنے میں مددگار ہے۔",
                "Comprehensive balance of full-body functional strength, core stabilization, and cardiovascular wellness.": "متوازن صحت کے لیے پورے جسم کی طاقت، پیٹ کے مسلز، اور دل کی صحت کا مجموعہ۔"
            }.get(goal_summary, goal_summary)
            
            translation_map = {
                "4 Active Training Days, 3 Recovery Days": "4 دن سرگرم ورزش، 3 دن آرام",
                "Diabetic Guideline: Best performed 30-45 mins after meals to optimize glucose uptake. Keep hydration high and avoid extreme fasting exertion.": "شوگر گائیڈ لائن: گلوکوز کی سطح کو متوازن رکھنے کے لیے کھانے کے 30-45 منٹ بعد ورزش کریں۔ ہائیڈریشن برقرار رکھیں اور روزے کی حالت میں شدید مشقت سے گریز کریں۔",
                "Hypertension Guideline: Maintain continuous steady breathing on all repetitions. Strictly avoid holding your breath (Valsalva maneuver).": "ہائی بلڈ پریشر گائیڈ لائن: ہر ریپ پر مسلسل اور ہموار سانس لیں۔ سانس روکنے (Valsalva) سے سختی سے پرہیز کریں۔",
                "Joint Health: All exercises are low-impact and joint-sparing. If you feel any sharp joint discomfort, reduce range of motion.": "جوڑوں کی صحت: تمام ورزشیں جوڑوں کے لیے محفوظ ہیں۔ اگر جوڑوں میں تیز درد محسوس ہو، تو ورزش کا دائرہ کم کریں۔",
                "General Health: Hydrate before, during, and after exercise. Listen to your body and rest when needed.": "عمومی صحت: ورزش سے پہلے، دوران اور بعد میں پانی پییں۔ اپنے جسم کی سنیں اور ضرورت پڑنے پر آرام کریں۔",
                "Active recovery day: Focus on muscle replenishment, protein intake, and getting 8 hours of quality sleep.": "بحالی کا دن: پٹھوں کی بحالی، پروٹین کے استعمال اور 8 گھنٹے کی معیاری نیند پر توجہ دیں۔",
                "Recharge day: Keep hydration optimal and focus on nutritious whole-food recovery meals.": "ریچارج کا دن: ہائیڈریشن کو بہترین رکھیں اور صحت بخش کھانوں پر توجہ دیں۔",
                "Complete rest day to allow muscle protein synthesis and systemic nervous recovery.": "مکمل آرام کا دن تاکہ عضلات بحال ہو سکیں اور اعصابی نظام کو سکون ملے۔",
                "Upper Body & Core Activation": "اوپری جسم اور پیٹ کے مسلز کی ورزش",
                "Lower Body & Posture": "نچلے جسم اور جسمانی ساخت کی ورزش",
                "Muscle Repair, Hydration & Light Walk": "پٹھوں کی بحالی، ہائیڈریشن اور ہلکی چہل قدمی",
                "Full-Body Functional Strength": "پورے جسم کی طاقت کی ورزش",
                "Metabolic Endurance & Aerobic Stamina": "میٹابولک برداشت اور کارڈیو انڈورنس",
                "Joint Decompression & Light Mobility": "جوڑوں کی لچک اور نقل و حرکت",
                "Weekly Reset & Mental Well-being": "ہفتہ وار آرام اور ذہنی سکون",
                "Rest & Active Recovery": "آرام اور بحالی",
                "Rest & Active Mobility": "آرام اور لچک",
                "Full Body Rest & Regeneration": "مکمل آرام اور بحالی",
                "5 mins dynamic arm circles, shoulder rolls, and torso twists.": "5 منٹ بازو گھمانا، کندھے کی گردش، اور دھڑ کے موڑ۔",
                "5 mins leg swings, hip openers, and ankle rotations.": "5 منٹ ٹانگیں ہلانا، کولہے کھولنا، اور ٹخنوں کی گردش۔",
                "Optional: 10 mins gentle walking or leisurely stroll.": "چہل قدمی: 10 منٹ ہلکی واک یا تفریحی چہل قدمی۔",
                "5 mins marching in place, cat-cow stretches, and hip rotations.": "5 منٹ ایک جگہ مارچ، کیٹ کاؤ اسٹریچ، اور ہپ روٹیشن۔",
                "5 mins step-touches and gentle dynamic stretching.": "5 منٹ ہلکے قدم اور متحرک اسٹریچنگ۔",
                "Optional: 15 mins relaxed outdoor walk.": "چہل قدمی: 15 منٹ باہر پرسکون چہل قدمی۔",
                "5 mins chest opening stretch, overhead lat stretch, and deep diaphragmatic breathing.": "5 منٹ سینے کا اسٹریچ، کندھے کا اسٹریچ، اور گہرے سانس لینا۔",
                "5 mins hamstring stretch, quad stretch, and calf wall stretch.": "5 منٹ ہیمسٹرنگ، ران کا اسٹریچ، اور پنڈلی کا اسٹریچ۔",
                "10 mins full-body restorative mobility and gentle stretching.": "10 منٹ پورے جسم کی بحالی اور ہلکی اسٹریچنگ۔",
                "5 mins child's pose, seated forward fold, and gentle spinal twist.": "5 منٹ چائلڈ پوز، آگے جھکنا، اور ریڑھ کی ہڈی کا ہلکا موڑ۔",
                "5 mins deep breathing and quad/hamstring cooldown stretches.": "5 منٹ گہرے سانس اور ران و ہیمسٹرنگ کے اسٹریچز۔",
                "10 mins foam rolling or gentle yoga stretches.": "10 منٹ فوم رولنگ یا ہلکے یوگا اسٹریچز۔",
                "Deep relaxation and preparation for the upcoming week.": "گہرا آرام اور اگلے ہفتے کی تیاری۔",
                "Dumbbell/Bodyweight Push-Ups": "پش اپس",
                "Dumbbell Overhead Shoulder Press": "ڈمبل شولڈر پریس",
                "Bodyweight Tricep Dips": "ٹرائیسیپ ڈپس",
                "Resistance Band / Dumbbell Rows": "ڈمبل یا بینڈ روز",
                "Bicep Curls": "بائیسیپ کرلز",
                "Plank Hold": "پلانک ہولڈ",
                "Bodyweight Goblet Squats": "گوبلیٹ اسکوائٹس",
                "Glute Bridges": "گلوٹ برجز",
                "Calf Raises": "پنڈلیوں کی ورزش",
                "Bodyweight Air Squats": "ایئر اسکوائٹس",
                "Incline Push-Ups / Wall Push-Ups": "دیوار پر پش اپس",
                "Brisk Walking / Step-Ups": "تیز واک یا اسٹیپ اپس",
                "Resistance Band Rows": "ریزسٹنس بینڈ روز",
                "Standing Knee-to-Elbow Marches": "گھٹنے سے کہنی مارچ",
                "Glute Bridge Pulses": "گلوٹ برج پلسز",
                "Zone-2 Aerobic Walk / Light Cycling": "زون-2 ہلکی واک یا سائیکلنگ",
                "Bird-Dog Holds": "برڈ ڈاگ ہولڈز",
                "Bodyweight Squats to Chair": "کرسی کے ساتھ اسکوائٹس",
                "Doorway Row / Band Pull-Apart": "بینڈ پل اپارٹ",
                "Standing Calf Raises": "کھڑے ہوکر پنڈلیوں کی ورزش",
                "Brisk Walking / Low-Impact Cardio": "ہلکا کارڈیو یا تیز چہل قدمی",
                "Dead Bug Core Engagement": "ڈیڈ بگ کور ورزش",
                "Wall Angels": "وال اینجلز",
                "Chest & Triceps": "سینہ اور ٹرائیسیپس",
                "Deltoids": "کندھے",
                "Triceps": "ٹرائیسیپس",
                "Lats & Upper Back": "پیٹھ کا اوپری حصہ",
                "Biceps": "بائیسیپس",
                "Core": "پیٹ کے مسلز",
                "Quadriceps & Glutes": "رانیں اور ہپس",
                "Glutes & Hamstrings": "کولہے اور ہیمسٹرنگ",
                "Calves": "پنڈلیاں",
                "Quads & Glutes": "رانیں اور کولہے",
                "Chest & Arms": "سینہ اور بازو",
                "Cardio Endurance": "کارڈیو انڈورنس",
                "Back & Posture": "پیٹھ اور کمر",
                "Core & Cardio": "پیٹ اور کارڈیو",
                "Glutes": "کولہے",
                "Cardiovascular System": "دل کا نظام",
                "Core & Spinal Stability": "پیٹ اور کمر کا استحکام",
                "Legs & Mobility": "ٹانگیں اور لچک",
                "Upper Back": "کمر کا اوپری حصہ",
                "Lower Legs": "ٹانگوں کا نچلا حصہ",
                "Heart & Lungs": "دل اور پھیپھڑے",
                "Deep Abdominals": "پیٹ کے اندرونی مسلز",
                "Hips & Glutes": "کولہے اور ہپس",
                "Shoulder Mobility": "کندھوں کی لچک",
                "10-12 reps": "10-12 بار",
                "10-15 reps": "10-15 بار",
                "12 reps": "12 بار",
                "12-15 reps": "12-15 بار",
                "45 seconds": "45 سیکنڈ",
                "15 reps": "15 بار",
                "20 reps": "20 بار",
                "2 mins": "2 منٹ",
                "25 mins": "25 منٹ",
                "10 each side": "ہر طرف 10 بار",
                "20 mins": "20 منٹ",
                "10 reps": "10 بار",
                "Keep core tight, elbows at 45 degrees": "پیٹ سخت رکھیں، کہنیاں 45 ڈگری پر",
                "Press straight up, avoid arching lower back": "سیدھا اوپر پریس کریں، کمر موڑنے سے بچیں",
                "Control descent, push through palms": "نیچے جانے پر کنٹرول رکھیں، ہتھیلیوں سے زور لگائیں",
                "Squeeze shoulder blades at top": "اوپر کندھوں کے بلیڈ کو آپس میں بھینچیں",
                "Keep elbows pinned to sides": "کہنیوں کو اطراف سے جوڑ کر رکھیں",
                "No swinging": "جھٹکا نہ دیں",
                "Straight line from head to heels": "سر سے ایڑی تک سیدھی لائن بنائیں",
                "Breathe continuously": "مستعمل سانس لیتے رہیں",
                "Chest up, knees tracking toes": "سینہ اوپر، گھٹنے پنجوں کی سیدھ میں",
                "Drive through heels, squeeze glutes at top": "ایڑیوں سے زور لگائیں، کولہے اوپر بھینچیں",
                "Avoid hyperextending spine": "ریڑھ کی ہڈی کو زیادہ موڑنے سے بچیں",
                "Full stretch and contraction at top": "اوپر پورا کھچاؤ محسوس کریں",
                "Hold wall for balance": "توازن کے لیے دیوار کا سہارا لیں",
                "Chest up, drive through heels": "سینہ اوپر، ایڑیوں سے زور لگائیں",
                "Core engaged": "پیٹ سخت رکھیں",
                "Pump arms lightly": "بازوؤں کو ہلکا حرکت دیں",
                "Draw elbows back smoothly": "کہنیوں کو پیچھے ہمواری سے کھینچیں",
                "Engage abs with each knee raise": "ہر بار گھٹنا اٹھانے پر پیٹ کو سکڑیں",
                "Squeeze glutes at top of bridge": "برج کے اوپر گلوٹس کو سکیڑیں",
                "Breathe rhythmically through nose": "ناک سے تال میں سانس لیں",
                "Reach arm and opposite leg parallel to floor": "بازو اور مخالف ٹانگ فرش کے متوازی پھیلائیں",
                "Keep pelvis level": "کولہے متوازن رکھیں",
                "Sit back gently to chair and stand": "آہستہ سے کرسی پر بیٹھیں اور کھڑے ہوں",
                "Knees behind toes": "گھٹنے پنجوں سے پیچھے رکھیں",
                "Squeeze shoulder blades": "کندھے کے بلیڈ سکیڑیں",
                "Gentle posture alignment": "سیدھی جسمانی ساخت رکھیں",
                "Hold for 1 sec at top": "اوپر 1 سیکنڈ کے لیے رکیں",
                "Maintain conversational pace": "بات چیت کی رفتار برقرار رکھیں",
                "Press lower back flat into floor": "کمر کا نچلا حصہ فرش پر فلیٹ رکھیں",
                "Slide arms along wall smoothly": "دیوار کے ساتھ بازوؤں کو ہمواری سے سلائیڈ کریں",
                "Keep steady breathing": "سانس بحال رکھیں",
                "Use moderate weight": "درمیانہ وزن استعمال کریں",
                "Avoid excessive shoulder extension": "کندھوں کو زیادہ پھیلانے سے بچیں",
                "Hinge at hips with flat back": "کمر سیدھی رکھ کر کولہے سے جھکیں",
                "Low-impact form": "کم دباؤ والا فارم رکھیں",
                "Keep steady pace": "برابر رفتار رکھیں",
                "Exhale on push": "پش کرتے وقت سانس باہر نکالیں",
                "Maintain steady rhythm": "مسلسل تال برقرار رکھیں",
                "Keep shoulders down": "کندھے نیچے رکھیں",
                "Low-impact continuous movement": "مسلسل اور کم جھٹکے والی حرکت",
                "Gentle on lower back": "کمر کے نچلے حصے پر نرمی رکھیں",
                "Stay hydrated": "پانی پیتے رہیں",
                "Gentle range of motion": "آہستہ اور نرمی سے حرکت کریں",
            }
            
            weekly_freq = translation_map.get("4 Active Training Days, 3 Recovery Days", "4 Active Training Days, 3 Recovery Days")
            translated_med_notes = [translation_map.get(m, m) for m in med_notes]
            
            for day in schedule:
                # Resolve title prefix mapping safely
                original_title = day.workout_title
                prefix_map = {
                    "Progressive Hypertrophy & Strength Split - Day 1": "عضلات بڑھانے اور طاقت کا منصوبہ - دن 1",
                    "Progressive Hypertrophy & Strength Split - Day 2": "عضلات بڑھانے اور طاقت کا منصوبہ - دن 2",
                    "Progressive Hypertrophy & Strength Split - Day 3": "عضلات بڑھانے اور طاقت کا منصوبہ - دن 3",
                    "Progressive Hypertrophy & Strength Split - Day 4": "عضلات بڑھانے اور طاقت کا منصوبہ - دن 4",
                    "Metabolic Fat-Loss & Cardiovascular Circuit - Day 1": "چربی جلانے اور کارڈیو کا سرکٹ - دن 1",
                    "Metabolic Fat-Loss & Cardiovascular Circuit - Day 2": "چربی جلانے اور کارڈیو کا سرکٹ - دن 2",
                    "Metabolic Fat-Loss & Cardiovascular Circuit - Day 3": "چربی جلانے اور کارڈیو کا سرکٹ - دن 3",
                    "Metabolic Fat-Loss & Cardiovascular Circuit - Day 4": "چربی جلانے اور کارڈیو کا سرکٹ - دن 4",
                    "Balanced Functional Health & Mobility Plan - Day 1": "فنکشنل صحت اور نقل و حرکت کا منصوبہ - دن 1",
                    "Balanced Functional Health & Mobility Plan - Day 2": "فنکشنل صحت اور نقل و حرکت کا منصوبہ - دن 2",
                    "Balanced Functional Health & Mobility Plan - Day 3": "فنکشنل صحت اور نقل و حرکت کا منصوبہ - دن 3",
                    "Balanced Functional Health & Mobility Plan - Day 4": "فنکشنل صحت اور نقل و حرکت کا منصوبہ - دن 4",
                }
                day.workout_title = prefix_map.get(original_title, translation_map.get(original_title, original_title))
                day.target_focus = translation_map.get(day.target_focus, day.target_focus)
                day.warm_up = translation_map.get(day.warm_up, day.warm_up)
                day.cool_down = translation_map.get(day.cool_down, day.cool_down)
                day.clinical_safety_notes = translation_map.get(day.clinical_safety_notes, day.clinical_safety_notes)
                
                for ex in day.exercises:
                    ex.name = translation_map.get(ex.name, ex.name)
                    ex.target_muscle = translation_map.get(ex.target_muscle, ex.target_muscle)
                    ex.reps = translation_map.get(ex.reps, ex.reps)
                    ex.form_cues = translation_map.get(ex.form_cues, ex.form_cues)
                    ex.precautions = translation_map.get(ex.precautions, ex.precautions)
            
            return {
                "plan_name": translated_plan_name,
                "goal_summary": translated_goal_summary,
                "weekly_frequency": weekly_freq,
                "medical_considerations": translated_med_notes,
                "weekly_schedule": [d.model_dump() for d in schedule]
            }

        return {
            "plan_name": plan_name,
            "goal_summary": goal_summary,
            "weekly_frequency": "4 Active Training Days, 3 Recovery Days",
            "medical_considerations": med_notes,
            "weekly_schedule": [d.model_dump() for d in schedule]
        }
