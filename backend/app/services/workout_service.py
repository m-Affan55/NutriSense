import json
import logging
from typing import Dict, Any, List
from google.genai import types
from app.schemas.workout import WorkoutPlanResponse, WorkoutDay, Exercise
from app.services.gemini_pool import gemini_pool

logger = logging.getLogger("workout_service")

class WorkoutService:
    @staticmethod
    def generate_workout_plan(profile: Dict[str, Any], is_ramadan: bool = False) -> Dict[str, Any]:
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
            return WorkoutService._generate_clinical_fallback(profile, is_ramadan)

    @staticmethod
    def _generate_clinical_fallback(profile: Dict[str, Any], is_ramadan: bool = False) -> Dict[str, Any]:
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

        return {
            "plan_name": plan_name,
            "goal_summary": goal_summary,
            "weekly_frequency": "4 Active Training Days, 3 Recovery Days",
            "medical_considerations": med_notes,
            "weekly_schedule": [d.model_dump() for d in schedule]
        }
