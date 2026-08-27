import datetime
import json
import math
from app.core.config import settings
from app.db.supabase_client import get_supabase_admin_client


class ReportService:
    @staticmethod
    def generate_weekly_report(user_id: str, language: str = "en") -> dict:
        """
        Gathers user health profile, 7-day meal logs, and hydration data,
        computes compliance metrics and score, and generates a personalized
        AI narrative summary via Google Gemini.
        """
        supabase = get_supabase_admin_client()

        # 1. Fetch user profile & health targets
        profile_res = supabase.table('health_profiles').select('*').eq('user_id', user_id).maybe_single().execute()
        health_profile = profile_res.data or {}

        user_info_res = supabase.table('profiles').select('*').eq('id', user_id).maybe_single().execute()
        user_info = user_info_res.data or {}

        # Default targets
        target_calories = int(health_profile.get('daily_calorie_target') or 2000)
        target_protein = int(health_profile.get('daily_protein_g') or 150)
        target_carbs = int(health_profile.get('daily_carbs_g') or 250)
        target_fat = int(health_profile.get('daily_fat_g') or 70)
        target_water = 2500  # ml/day target

        # 2. Fetch past 7 days of meal logs and water logs
        now_utc = datetime.datetime.now(datetime.timezone.utc)
        end_date = now_utc.date()
        start_date = end_date - datetime.timedelta(days=7)

        start_iso = f"{start_date.isoformat()}T00:00:00+00:00"
        end_iso = f"{end_date.isoformat()}T23:59:59+00:00"

        meals_res = supabase.table('meal_logs').select('*').eq('user_id', user_id).gte('logged_at', start_iso).lte('logged_at', end_iso).order('logged_at', ascending=True).execute()
        meals = meals_res.data or []

        water_res = supabase.table('water_logs').select('*').eq('user_id', user_id).gte('logged_at', start_iso).lte('logged_at', end_iso).execute()
        water_logs = water_res.data or []

        # 3. Aggregate daily statistics
        daily_stats = {}
        for i in range(7):
            d = (start_date + datetime.timedelta(days=i + 1)).isoformat()
            daily_stats[d] = {
                "date": d,
                "calories": 0,
                "protein_g": 0,
                "carbs_g": 0,
                "fat_g": 0,
                "water_ml": 0,
                "meal_count": 0,
                "meals": []
            }

        for m in meals:
            logged_at = m.get('logged_at', '')
            if logged_at:
                day_key = logged_at.split('T')[0]
                if day_key in daily_stats:
                    cals = int(m.get('total_calories') or 0)
                    prot = int(m.get('protein_g') or 0)
                    carbs = int(m.get('carbs_g') or 0)
                    fat = int(m.get('fat_g') or 0)

                    daily_stats[day_key]["calories"] += cals
                    daily_stats[day_key]["protein_g"] += prot
                    daily_stats[day_key]["carbs_g"] += carbs
                    daily_stats[day_key]["fat_g"] += fat
                    daily_stats[day_key]["meal_count"] += 1
                    daily_stats[day_key]["meals"].append(m.get('notes') or m.get('meal_type') or 'Meal')

        for w in water_logs:
            logged_at = w.get('logged_at', '')
            if logged_at:
                day_key = logged_at.split('T')[0]
                if day_key in daily_stats:
                    daily_stats[day_key]["water_ml"] += int(w.get('amount_ml') or 0)

        # 4. Compute overall week compliance & health score
        days_adhered = 0
        total_calories_week = 0
        total_protein_week = 0
        total_carbs_week = 0
        total_fat_week = 0
        total_water_week = 0
        active_days = 0

        for d, s in daily_stats.items():
            c = s["calories"]
            total_calories_week += c
            total_protein_week += s["protein_g"]
            total_carbs_week += s["carbs_g"]
            total_fat_week += s["fat_g"]
            total_water_week += s["water_ml"]

            if s["meal_count"] > 0:
                active_days += 1
                # Adherence condition: within 20% of calorie goal
                if target_calories > 0 and abs(c - target_calories) / target_calories <= 0.20:
                    days_adhered += 1

        avg_daily_calories = round(total_calories_week / 7)
        avg_daily_protein = round(total_protein_week / 7)
        avg_daily_carbs = round(total_carbs_week / 7)
        avg_daily_fat = round(total_fat_week / 7)
        avg_daily_water = round(total_water_week / 7)

        # Calculate composite health score (0 - 100)
        calorie_score = min(50, round((days_adhered / 7) * 50))
        water_score = min(25, round((avg_daily_water / target_water) * 25)) if target_water > 0 else 20
        consistency_score = min(25, round((active_days / 7) * 25))
        health_score = max(35, min(98, calorie_score + water_score + consistency_score))

        # 5. Generate AI Narrative Insights using Gemini
        weekly_summary = ReportService._generate_ai_narrative(
            user_info=user_info,
            health_profile=health_profile,
            stats={
                "target_calories": target_calories,
                "target_protein": target_protein,
                "target_carbs": target_carbs,
                "target_fat": target_fat,
                "avg_daily_calories": avg_daily_calories,
                "avg_daily_protein": avg_daily_protein,
                "avg_daily_carbs": avg_daily_carbs,
                "avg_daily_fat": avg_daily_fat,
                "avg_daily_water": avg_daily_water,
                "days_adhered": days_adhered,
                "active_days": active_days,
                "health_score": health_score,
                "total_meals": len(meals),
            },
            daily_stats=list(daily_stats.values()),
            language=language
        )

        return {
            "status": "success",
            "health_score": health_score,
            "days_adhered": days_adhered,
            "weekly_summary": weekly_summary,
            "stats": {
                "avg_daily_calories": avg_daily_calories,
                "target_calories": target_calories,
                "avg_daily_protein_g": avg_daily_protein,
                "target_protein_g": target_protein,
                "avg_daily_carbs_g": avg_daily_carbs,
                "target_carbs_g": target_carbs,
                "avg_daily_fat_g": avg_daily_fat,
                "target_fat_g": target_fat,
                "avg_daily_water_ml": avg_daily_water,
                "target_water_ml": target_water,
                "total_meals_logged": len(meals),
                "active_days": active_days,
            },
            "daily_breakdown": list(daily_stats.values()),
        }

    @staticmethod
    def _generate_ai_narrative(user_info: dict, health_profile: dict, stats: dict, daily_stats: list, language: str) -> str:
        """Invokes Gemini to create a rich weekly progress analysis."""
        try:
            from google.genai import types
            from app.services.gemini_pool import gemini_pool

            conditions = ', '.join(health_profile.get('medical_conditions', [])) or 'None'
            allergies = ', '.join(health_profile.get('allergens', [])) or 'None'
            diet = ', '.join(health_profile.get('dietary_restrictions', [])) or 'Standard'
            goal = health_profile.get('goal', 'healthy lifestyle')
            full_name = user_info.get('full_name') or 'User'

            is_urdu = language == 'ur'

            system_instruction = (
                "You are the Chief Clinical Nutritionist at NutriSense. "
                "Write an empowering, insightful, and structured weekly nutrition review. "
                "Highlight accomplishments, identify caloric/macro variances, analyze hydration, "
                "and give 3 clear actionable micro-goals for the upcoming week."
            )

            prompt = f"""
            User: {full_name}
            Health Goal: {goal}
            Medical Conditions: {conditions}
            Dietary Preferences: {diet}
            Allergies: {allergies}

            Weekly Performance Data:
            - Health Adherence Score: {stats['health_score']}%
            - Days Targets Met: {stats['days_adhered']}/7 days
            - Total Meals Logged: {stats['total_meals']}
            - Average Calories: {stats['avg_daily_calories']} kcal (Target: {stats['target_calories']} kcal)
            - Average Protein: {stats['avg_daily_protein_g']}g (Target: {stats['target_protein_g']}g)
            - Average Carbs: {stats['avg_daily_carbs_g']}g (Target: {stats['target_carbs_g']}g)
            - Average Fat: {stats['avg_daily_fat_g']}g (Target: {stats['target_fat_g']}g)
            - Average Hydration: {stats['avg_daily_water_ml']} ml/day (Target: 2500 ml/day)

            Language: {"Urdu (use natural, polite Urdu text with Jameel Nastaleeq style)" if is_urdu else "English"}

            Structure your response into 3 concise sections:
            1. 🏆 Weekly Wins & Highlights
            2. 🔍 Macro & Hydration Assessment
            3. 🎯 3 Key Action Steps for Next Week
            """

            response = gemini_pool.generate_content(
                model='gemini-3.5-flash-lite',
                contents=[prompt],
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    temperature=0.3,
                ),
            )

            if response and response.text:
                return response.text.strip()
        except Exception as e:
            print(f"[ReportService] Gemini narrative error: {e}")

        # Fallback summary if AI call encounters network or quota error
        if language == 'ur':
            return (
                f"🏆 ہفتہ وار کارکردگی: آپ نے اس ہفتے {stats['days_adhered']} دن اپنے اہداف مکمل کیے۔ "
                f"آپ کا اوسط کیلوری انٹیک {stats['avg_daily_calories']} kcal رہا۔ "
                f"اگلے ہفتے کے لیے پروٹین کی مقدار بڑھائیں اور روزانہ کم از کم 2.5 لیٹر پانی کا ہدف مکمل کریں۔"
            )
        return (
            f"🏆 Weekly Performance: You successfully met your dietary goals on {stats['days_adhered']} out of 7 days "
            f"with an overall Health Score of {stats['health_score']}%. Your average caloric intake was {stats['avg_daily_calories']} kcal/day "
            f"against your target of {stats['target_calories']} kcal. Continue staying consistent with your daily hydration and protein targets."
        )

    @staticmethod
    def generate_pdf_report(user_id: str, language: str = "en") -> bytes:
        """
        Generates a professional weekly PDF clinical summary.
        Uses pure-Python standards-compliant PDF generation for 100% zero-dependency reliability.
        """
        report_data = ReportService.generate_weekly_report(user_id=user_id, language=language)
        stats = report_data.get("stats", {})
        summary_text = report_data.get("weekly_summary", "")
        health_score = report_data.get("health_score", 75)
        days_adhered = report_data.get("days_adhered", 5)

        # Generate clean standard PDF 1.4 binary stream
        pdf_bytes = ReportService._build_pdf_stream(
            title="NutriSense Weekly Nutrition & Clinical Report",
            health_score=health_score,
            days_adhered=days_adhered,
            stats=stats,
            summary=summary_text,
            date_str=datetime.date.today().strftime("%B %d, %Y")
        )
        return pdf_bytes

    @staticmethod
    def _build_pdf_stream(title: str, health_score: int, days_adhered: int, stats: dict, summary: str, date_str: str) -> bytes:
        """Constructs a clean PDF document buffer."""
        # Sanitize text for standard PDF Type 1 fonts (ASCII / Latin-1)
        safe_summary = summary.replace('\r', '').replace('’', "'").replace('“', '"').replace('”', '"').replace('—', '-')
        # Clean unicode characters that cannot render in standard Helvetica
        safe_summary_clean = ''.join(c if ord(c) < 128 else ' ' for c in safe_summary)

        lines = []
        for raw_line in safe_summary_clean.split('\n'):
            raw_line = raw_line.strip()
            if not raw_line:
                lines.append("")
                continue
            # Word wrap at ~80 characters
            words = raw_line.split(' ')
            current = ""
            for w in words:
                if len(current) + len(w) + 1 > 75:
                    lines.append(current)
                    current = w
                else:
                    current = f"{current} {w}".strip()
            if current:
                lines.append(current)

        content_stream_lines = [
            "BT",
            "/F1 20 Tf",
            "40 760 Td",
            "(NutriSense - Clinical Nutrition Weekly Report) Tj",
            "/F2 10 Tf",
            "0 -20 Td",
            f"(Report Generated on: {date_str}) Tj",
            "/F2 12 Tf",
            "0 -25 Td",
            f"(Health Adherence Score: {health_score}%     |     Goals Met: {days_adhered} / 7 Days) Tj",
            "0 -20 Td",
            f"(Avg Daily Calories: {stats.get('avg_daily_calories', 0)} kcal  (Target: {stats.get('target_calories', 2000)} kcal)) Tj",
            "0 -16 Td",
            f"(Avg Daily Protein: {stats.get('avg_daily_protein_g', 0)}g   |   Carbs: {stats.get('avg_daily_carbs_g', 0)}g   |   Fat: {stats.get('avg_daily_fat_g', 0)}g) Tj",
            "0 -16 Td",
            f"(Avg Hydration: {stats.get('avg_daily_water_ml', 0)} ml/day  (Target: 2500 ml/day)) Tj",
            "/F1 14 Tf",
            "0 -30 Td",
            "(AI Nutritionist Clinical Review & Action Plan:) Tj",
            "/F2 9.5 Tf",
            "0 -18 Td",
        ]

        y_offset = 0
        for l in lines[:36]:  # Fit up to 36 formatted lines
            safe_l = l.replace('(', '\\(').replace(')', '\\)')
            content_stream_lines.append(f"({safe_l}) Tj")
            content_stream_lines.append("0 -13 Td")
            y_offset += 13

        content_stream_lines.append("ET")
        stream_data = "\n".join(content_stream_lines).encode("latin-1", errors="replace")

        # Assemble PDF Objects
        obj1 = b"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
        obj2 = b"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
        obj3 = b"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources 4 0 R /Contents 5 0 R >>\nendobj\n"
        obj4 = (
            b"4 0 obj\n<< /Font << "
            b"/F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >> "
            b"/F2 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> "
            b">> >>\nendobj\n"
        )
        obj5 = f"5 0 obj\n<< /Length {len(stream_data)} >>\nstream\n".encode("latin-1") + stream_data + b"\nendstream\nendobj\n"

        header = b"%PDF-1.4\n"
        body = obj1 + obj2 + obj3 + obj4 + obj5

        xref_pos = len(header) + len(body)
        offsets = [
            0,
            len(header),
            len(header) + len(obj1),
            len(header) + len(obj1) + len(obj2),
            len(header) + len(obj1) + len(obj2) + len(obj3),
            len(header) + len(obj1) + len(obj2) + len(obj3) + len(obj4),
        ]

        xref = f"xref\n0 6\n0000000000 65535 f \n" + "".join(f"{off:010d} 00000 n \n" for off in offsets[1:])
        trailer = f"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n"

        return header + body + xref.encode("latin-1") + trailer.encode("latin-1")
