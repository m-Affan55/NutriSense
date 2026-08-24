# NutriSense — Adversarial QA Report

> Full code-path trace across Flutter frontend + FastAPI backend + Gemini AI services.
> Every issue includes the **exact code** that causes it, not just descriptions.

---

## Category 1: Network Failures

### Issue 1: `estimate_food_macros` silently returns fake hardcoded nutrition on ANY failure — user unknowingly logs wrong data

- **Where**: [gemini_service.py L138-175](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/gemini_service.py#L138-L175)
- **User action**: User types "2 Aloo Parathas and 1 Chai" in Manual Log → taps "Log Meal with AI" → backend is down or Gemini rate-limited
- **What happens**:
```python
# gemini_service.py L167-175
except Exception as e:
    # Safe heuristic fallback
    return {
        "name": query.title(),
        "calories": 450,
        "protein_g": 15.0,
        "carbs_g": 55.0,
        "fat_g": 18.0
    }
```
The frontend receives `200 OK` with plausible-looking but completely fabricated data. There is **no indicator** in the response that this is a fallback — no `"source": "fallback"` field, no flag.
- **Bad outcome**: User logs a meal believing AI analyzed it. A diabetic user types "1 plate Jalebi" (≈500kcal, 70g carbs) but gets logged as 450kcal/55g carbs. They eat more thinking they have room. Nutrition tracking becomes unreliable. **All downstream features (weekly report, habit score, escalation) are based on polluted data.**
- **Severity**: **Critical** — silently corrupts the core data the entire app's safety features depend on.
- **Fix**:
```diff
# gemini_service.py
 except Exception as e:
-    # Safe heuristic fallback
     return {
         "name": query.title(),
-        "calories": 450,
-        "protein_g": 15.0,
-        "carbs_g": 55.0,
-        "fat_g": 18.0
+        "calories": 0,
+        "protein_g": 0.0,
+        "carbs_g": 0.0,
+        "fat_g": 0.0,
+        "is_fallback": True,
+        "fallback_reason": str(e),
     }
```
Frontend must check `is_fallback` and show a warning: "AI couldn't analyze this meal. Values may be inaccurate — please review before logging."

---

### Issue 2: Manual log frontend swallows API failure and still uses hardcoded macros

- **Where**: [manual_log_screen.dart L103-134](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart#L103-L134)
- **User action**: User types meal → taps "Log Meal with AI" while offline or backend down
- **What happens**:
```dart
// manual_log_screen.dart L103-134
int calories = 450;
double proteinG = 15.0;
double carbsG = 55.0;
double fatG = 18.0;
// ...
try {
    // API call
} catch (_) {
    // Offline fallback: Heuristic estimation
    calories = 480;
    proteinG = 16.0;
    carbsG = 60.0;
    fatG = 18.0;
}
// Proceeds to save these hardcoded values as real data
```
Both the backend fallback (Issue 1) AND the frontend catch produce fake macros. **Double fallback = guaranteed garbage data logged silently.**
- **Bad outcome**: User thinks they logged "Chicken Biryani" as 480 kcal (real value: ~650-750). Accumulated errors skew weekly reports.
- **Severity**: **Critical** — compounds Issue 1; the user never learns the data is fake.
- **Fix**: When the API call fails, show a dialog: "Couldn't calculate nutrition. Enter approximate values manually or retry when online." Do NOT auto-log fabricated numbers.

---

### Issue 3: No HTTP timeout on AI coach chat call — UI stuck on "Typing..." forever

- **Where**: [ai_coach_screen.dart L350-358](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L350-L358)
- **User action**: User sends a message to AI coach while on a slow network
- **What happens**:
```dart
// ai_coach_screen.dart L350-358
final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({...}),
);
// No .timeout() — waits indefinitely
```
Compare to barcode scanner which has `.timeout(const Duration(seconds: 60))` at [barcode_scanner_screen.dart L75](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/barcode_scanner_screen.dart#L75).
- **Bad outcome**: The "Typing..." indicator shows forever. User cannot interact. If in voice mode, the state machine stays in `VoiceAssistantState.processing` and the mic/TTS never recovers.
- **Severity**: **High**
- **Fix**: Add `.timeout(const Duration(seconds: 45))` and catch `TimeoutException`.

---

### Issue 4: USDA API failure silently returns all-zero macros that get used as real data

- **Where**: [usda_service.py L60-71](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/usda_service.py#L60-L71) → consumed by [meals.py L43-60](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/meals.py#L43-L60)
- **User action**: User scans a meal image → USDA API times out or returns no results
- **What happens**:
```python
# usda_service.py returns:
return {"calories": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0}

# meals.py L49-55 uses these zeros:
grams = float(item.get("estimated_weight_g", 0))
ratio = grams / 100.0
item["calories"] = round(usda_macros["calories"] * ratio)  # 0 * anything = 0
```
- **Bad outcome**: User scans a plate of Biryani → sees "0 calories, 0g protein" → logs it → dashboard shows they ate nothing → no escalation triggers even if the meal is dangerous for their condition.
- **Severity**: **High**
- **Fix**: If USDA returns all zeros, fall back to Gemini estimation for that food item, or flag the item in the UI as "nutrition data unavailable."

---

## Category 2: Input Validation & Malformed Data

### Issue 5: Onboarding accepts weight=0, height=0, age=0 — causes division by zero in BMR calculation

- **Where**: Backend [health_profile.py L8-18](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/health_profile.py#L8-L18) (Pydantic model) and [L24-27](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/health_profile.py#L24-L27) (BMR calculation)
- **User action**: User enters weight=0, height=0, age=0 in onboarding (e.g., slides left to minimum)
- **What happens**:
```python
class OnboardingData(BaseModel):
    age: int          # No min constraint — accepts 0, -5
    weight_kg: float  # No min constraint — accepts 0.0
    height_cm: float  # No min constraint — accepts 0.0
    # ...

# BMR with weight=0, height=0, age=0:
bmr = (10 * 0) + (6.25 * 0) - (5 * 0) + 5  # = 5
daily_calories = 5 * 1.2 = 6  # Target: 6 kcal/day
daily_protein_g = int(0 * 2) = 0  # 0g protein target
remaining_calories = 6 - 0 - 0 = 6
daily_carbs_g = int(6 / 4) = 1  # 1g carbs target
```
Frontend slider `_age` starts at 25 with `min:13`, `_heightCm` at 170 with `min:100`, `_weightKg` at 70 with `min:30` — but the **backend** Pydantic model has **zero validation**. A modified HTTP request or Postman can bypass the frontend.
- **Bad outcome**: Daily calorie target of 6 kcal. Every meal triggers 100%+ overshoot. Health score permanently at minimum. If negative age is sent, BMR could become negative → negative calorie targets → all downstream calculations break.
- **Severity**: **High**
- **Fix**:
```diff
 class OnboardingData(BaseModel):
     user_id: str
-    age: int
-    weight_kg: float
-    height_cm: float
+    age: int = Field(..., ge=1, le=120)
+    weight_kg: float = Field(..., gt=0, le=500)
+    height_cm: float = Field(..., gt=0, le=300)
```

---

### Issue 6: No input length limit on AI coach message — can send megabytes of text to Gemini

- **Where**: [coach.py L15-18](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/coach.py#L15-L18)
- **User action**: User pastes a 50,000-character message into the chat
- **What happens**:
```python
class CoachRequest(BaseModel):
    user_id: str
    message: str       # No max_length
    history: List[ChatMessage]  # No max items
```
This entire payload + history is forwarded to Gemini. The `history` list is also unbounded.
- **Bad outcome**: Gemini token limit exceeded → 400/500 error → crash. Or worse: massive context causes rate-limiting across all API keys, DoS-ing the pool for all users.
- **Severity**: **Medium**
- **Fix**: Add `message: str = Field(..., max_length=5000)` and limit `history` to the last 20 messages in the Pydantic model.

---

### Issue 7: Barcode manual input accepts any string — non-numeric, emoji, injection

- **Where**: [barcode_scanner_screen.dart L469-487](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/barcode_scanner_screen.dart#L469-L487)
- **User action**: User taps "Enter Barcode Manually" → types `"><script>alert(1)</script>` or emoji 🍕
- **What happens**:
```dart
// barcode_scanner_screen.dart L469
TextField(
    controller: _manualBarcodeController,
    keyboardType: TextInputType.number,  // Soft keyboard hint only, NOT validation
    // No inputFormatters, no regex validation
```
The string is sent directly to the backend, which embeds it in SQL queries ([food_db_service.py L66-77](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/food_db_service.py#L66-L77)) and Gemini prompts ([gemini_service.py L248-271](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/gemini_service.py#L248-L271)).
- **Bad outcome**: Prompt injection into Gemini (user sends crafted barcode string that manipulates the AI prompt). SQL is parameterized so SQLi is safe, but Gemini prompt injection is not defended.
- **Severity**: **Medium**
- **Fix**: Add `inputFormatters: [FilteringTextInputFormatter.digitsOnly]` on frontend. On backend, validate barcode is digits-only: `if not re.match(r'^\d{4,14}$', req.barcode): raise HTTPException(400, "Invalid barcode format")`

---

## Category 3: Escalation / Clinic-Finder (Safety-Critical)

### Issue 8: Risk evaluator is ENTIRELY SKIPPED for users without medical conditions — even if they report acute symptoms

- **Where**: [risk_evaluator.py L17-18](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/risk_evaluator.py#L17-L18)
- **User action**: A user who selected "None" for medical conditions during onboarding types: "I'm feeling dizzy and fainted twice today"
- **What happens**:
```python
# risk_evaluator.py L17-18
if not (profile and profile.get("medical_conditions")) and not has_acute_symptom:
    return {"level": "none", "message": ""}
```
The `has_acute_symptom` check is keyword-based and catches "dizzy" and "faint". **This specific case IS handled.** But consider: "My blood sugar is 45 mg/dL" — the number "45" is NOT in the `critical_keywords` list `["350", "400", "500", ...]`. Only high numbers are checked, not dangerously LOW values (hypoglycemia).
- **Bad outcome**: A hypoglycemic user (blood sugar 30-60 mg/dL) gets **no escalation** because only values ≥350 are keyword-matched. Low blood sugar is a medical emergency.
- **Severity**: **Critical** — this is a life-safety gap.
- **Fix**: The keyword list must include low glucose indicators AND the Gemini evaluator should ALWAYS run when `has_acute_symptom` is true regardless of profile conditions. Add: `"low sugar", "blood sugar low", "hypoglycemia", "shakiness", "shaking", "sweating", "confusion", "blurred vision"` to the keyword list. Also add numeric range detection for blood sugar values < 70.

---

### Issue 9: Risk evaluator Gemini call fails → escalation silently dropped for non-keyword matches

- **Where**: [risk_evaluator.py L67-74](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/risk_evaluator.py#L67-L74)
- **User action**: A diabetic user says "I ate 3 slices of cake and feel very unwell" (no exact keyword match like "dizzy")
- **What happens**:
```python
except Exception as e:
    print(f"Risk Evaluator Error: {str(e)}")
    if has_acute_symptom:  # False — "unwell" is not in keyword list
        return {"level": "warning", ...}
    return {"level": "none", "message": ""}  # ← DROPPED
```
When Gemini is rate-limited/down AND the user's message doesn't match the hardcoded keywords exactly, the escalation is entirely suppressed even for a diabetic user reporting illness.
- **Bad outcome**: At-risk diabetic user reports feeling unwell after high sugar intake → no escalation → no clinic finder → no safety net.
- **Severity**: **Critical**
- **Fix**: When Gemini fails AND the user has medical conditions, default to `"warning"` level instead of `"none"`. The cost of a false positive (showing a clinic button) is negligible compared to missing a real emergency.

---

### Issue 10: Escalation alert is ONLY a notification — no guarantee user sees it, no blocking UI

- **Where**: [ai_coach_screen.dart L369-375](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L369-L375)
- **User action**: Escalation triggers but user has notifications disabled or the app is in background
- **What happens**:
```dart
if (escalationAlert != null) {
    ReminderManager.showRiskAlert(
        title: escalationAlert['level'] == 'critical' ? 'Urgent Clinical Safety Alert' : 'Dietary Health Alert',
        message: escalationAlert['message'] ?? 'Please review your nutrition advice.',
        level: escalationAlert['level'] ?? 'warning',
    );
}
```
`showRiskAlert` fires a local notification. If notifications are denied, this is a no-op. The escalation IS also embedded in the chat message bubble (L837-909), but only if the user scrolls down to see it.
- **Bad outcome**: Critical escalation fires → user backgrounded the app → notification permission denied → user never sees it. The in-chat escalation banner exists but is not a blocking/modal UI.
- **Severity**: **High**
- **Fix**: For `critical` level alerts, show a blocking `showDialog` in addition to the notification. The dialog should require explicit dismissal and contain the "Find Affordable Care" button.

---

### Issue 11: Clinic finder with location denied shows stale hardcoded Karachi clinics to users ANYWHERE in the world

- **Where**: [clinic_finder_screen.dart L41-179](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/clinic_finder_screen.dart#L41-L179) (hardcoded `_allClinics`)
- **User action**: User is in Islamabad/Peshawar/Dubai → gets escalation → opens clinic finder → location denied
- **What happens**:
```dart
void _useFallback(String msg) {
    // Shows _allClinics which are ONLY Karachi + 4 Lahore hospitals
    setState(() {
        _usingDynamic = false;  // Uses hardcoded list
        _isLoading = false;
    });
}
```
- **Bad outcome**: A user in Islamabad sees "Jinnah Hospital Karachi — 4.1 km" with a call button. The distance is wrong. They call a hospital 1000km away. At-risk users waste critical time.
- **Severity**: **High**
- **Fix**: When location is unavailable, show a clear message: "We couldn't determine your location. Please search for 'hospital near me' on Google Maps" with a direct Maps launch button, rather than showing misleading hardcoded distances.

---

### Issue 12: Overpass API returns zero results → fallback shows wrong-city clinics

- **Where**: [clinic_finder_screen.dart L257-260](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/clinic_finder_screen.dart#L257-L260)
- **User action**: User is in a rural area with GPS → Overpass API returns empty (no hospitals within 5km)
- **What happens**:
```dart
if (elements.isEmpty) {
    _useFallback("No clinics found nearby. Using fallback list.");
    return;
}
```
Falls back to the hardcoded Karachi/Lahore list — even though the user might be in Quetta.
- **Bad outcome**: Same as Issue 11. At-risk user sees irrelevant clinics.
- **Severity**: **High**
- **Fix**: Increase the Overpass search radius to 20km before falling back. If still empty, show a Google Maps deep link "Search hospitals near me" instead of the hardcoded list.

---

### Issue 13: Race condition — user can navigate away during escalation flow

- **Where**: [ai_coach_screen.dart L369-375](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L369-L375)
- **User action**: Risk is detected → escalation alert fires → user taps bottom nav to switch to Dashboard before they see it
- **What happens**: The `ReminderManager.showRiskAlert` fires as a notification (which may or may not show depending on permissions). The in-chat escalation widget is added to `_messages` at L379-385, but if the user has already navigated away from the chat screen, they never see it. When they return, they'd have to scroll through chat history to find it.
- **Bad outcome**: Critical safety escalation is buried in chat history.
- **Severity**: **Medium**
- **Fix**: For critical escalation, use a global overlay/dialog via `globalNavigatorKey` that appears regardless of which screen the user is on.

---

## Category 4: AI Coach (Gemini) Reliability

### Issue 14: Coach says "you're fine" but risk evaluator says escalate — contradiction shown to user

- **Where**: [coach.py L82-95](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/coach.py#L82-L95) — coach reply and risk evaluation are independent
- **User action**: Diabetic user says "I just ate 3 donuts, is that ok?" → Gemini coach says "That's fine in moderation!" → Risk evaluator (separate Gemini call) says "Warning: high sugar conflict with Diabetes"
- **What happens**:
```python
# coach.py L90
coach_reply = response.text  # "Enjoy in moderation!"

# coach.py L94-95 — completely separate call
risk = evaluate_health_risk(coach_reply, profile or {}, meals or [], user_message=req.message)
```
Both are returned to the frontend. The chat bubble shows the reassuring coach reply, AND the escalation alert underneath says it's dangerous.
- **Bad outcome**: User sees contradictory advice. They may trust the coach's "fine" and dismiss the safety alert as a false alarm.
- **Severity**: **High**
- **Fix**: When escalation fires at `warning` or `critical`, append a disclaimer to the coach reply: "⚠️ Note: Based on your health profile, please review the safety alert below before following this advice." Or re-run the coach response with the risk context injected.

---

### Issue 15: Chat history silently truncated to last 10 messages — safety context lost

- **Where**: [ai_coach_screen.dart L340-346](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L340-L346)
- **User action**: Long conversation where user mentioned "I have diabetes and my blood sugar was 300" in message #3, now on message #25
- **What happens**:
```dart
final startIdx = _messages.length > 11 ? _messages.length - 11 : 1;
for (int i = startIdx; i < _messages.length - 1; i++) {
    historyPayload.add({...});
}
```
Only the last 10 messages are sent to the backend. The backend `system_instruction` includes the user's health profile (fetched from DB), but the **conversational context** about specific symptoms, glucose readings, etc. is lost.
- **Bad outcome**: User reported a glucose reading of 350 earlier in the conversation. 15 messages later, they ask "should I exercise now?" The coach doesn't have the glucose context and may give dangerous advice.
- **Severity**: **Medium**
- **Fix**: Before truncating, scan all messages for safety-relevant keywords (numbers > 200, "dizzy", "faint", etc.) and prepend a safety summary to the system instruction. Or increase window size and use a summarization step.

---

### Issue 16: Raw Gemini error message forwarded to user on coach failure

- **Where**: [ai_coach_screen.dart L396-402](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L396-L402)
- **User action**: Gemini API returns an error (malformed response, unexpected exception)
- **What happens**:
```dart
} catch (e) {
    if (mounted) {
        // ...
        CustomToast.show(context, 'Chat error: ${e.toString()}');
```
The raw exception message (which may contain API keys, internal paths, or Gemini error details) is shown directly to the user via toast.
- **Bad outcome**: User sees technical error messages like "ClientException: Connection refused" or Gemini error payloads. Poor UX and potential info leak.
- **Severity**: **Low**
- **Fix**: Show a user-friendly message instead of `e.toString()`.

---

## Category 5: Voice Assistant

### Issue 17: Voice input auto-sends while a network request is already in flight — duplicate messages

- **Where**: [ai_coach_screen.dart L209-221](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L209-L221) → [L308-415](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L308-L415)
- **User action**: In voice mode → user says something → silence timer fires → `_stopListeningAndProcess` calls `_sendMessage` → TTS finishes → `_startListening()` fires again → user speaks quickly → another `_sendMessage` while the first HTTP call is still in flight
- **What happens**:
```dart
void _stopListeningAndProcess() async {
    // ...
    if (_controller.text.trim().isNotEmpty) {
        _sendMessage();  // No guard against concurrent calls
    }
}

Future<void> _sendMessage() async {
    // _isTyping is set to true, but nothing prevents a second call
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // No check for _isTyping — only empty text is guarded
```
- **Bad outcome**: Two concurrent HTTP requests to `/coach/chat`. Two coach replies appear. The voice state machine gets confused (speaking two responses simultaneously or the completion handler triggers listening while still processing).
- **Severity**: **Medium**
- **Fix**: Add `if (_isTyping) return;` at the top of `_sendMessage()`.

---

### Issue 18: Microphone permission denied on first tap — no error feedback on some platforms

- **Where**: [ai_coach_screen.dart L117-134](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L117-L134)
- **Traced code path**: The permission handling IS implemented:
```dart
Future<bool> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    final speechStatus = await Permission.speech.request();
    if (micStatus.isPermanentlyDenied || speechStatus.isPermanentlyDenied) {
        if (mounted) _showSettingsDialog();
        return false;
    }
    if (!micStatus.isGranted || !speechStatus.isGranted) {
        if (mounted) {
            CustomToast.show(context, 'Microphone permission is required...');
        }
        return false;
    }
    return true;
}
```
**Checked, no major issue found** — permissions are handled with both toast and settings dialog for permanently denied. The one gap: on Windows desktop, `Permission.microphone` and `Permission.speech` may not be supported by `permission_handler` and will throw or return unexpected statuses.
- **Severity**: **Low** (Windows edge case only)

---

### Issue 19: TTS interrupted by new `_speakText` call — previous utterance cut off

- **Where**: [ai_coach_screen.dart L236-252](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L236-L252)
- **Traced code path**:
```dart
Future<void> _speakText(String text) async {
    await _flutterTts.stop();  // ← Correctly stops previous utterance first
    setState(() { _voiceState = VoiceAssistantState.speaking; });
    await _flutterTts.speak(text);
}
```
**Checked, handled correctly** — `stop()` is called before starting new speech. The completion handler at L95-103 properly transitions state.

---

## Category 6: State Management & Navigation

### Issue 20: Rapid double-tap on "Confirm & Log" in barcode scan — duplicate meal entries

- **Where**: [barcode_scanner_screen.dart L346-381](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/barcode_scanner_screen.dart#L346-L381)
- **User action**: User taps "Confirm & Log" rapidly twice in the barcode result dialog
- **What happens**:
```dart
ElevatedButton(
    onPressed: () async {
        try {
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
                await Supabase.instance.client.from('meal_logs').insert({...});
            }
            if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context, true);
            }
        } catch (e) { ... }
    },
    // No _isLogging guard, no debounce, button not disabled during operation
```
Compare to ManualLogScreen which correctly has `onPressed: _isLogging ? null : _logMealWithAI` at [L509](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart#L509).
- **Bad outcome**: Meal logged twice in Supabase. Dashboard shows double calories. Weekly reports inflated.
- **Severity**: **Medium**
- **Fix**: Add a `bool _isLogging` guard and disable the button during the insert operation, matching ManualLogScreen's pattern.

---

### Issue 21: Rapid double-tap on "Confirm & Log" in scan meal result — same issue

- **Where**: [scan_meal_screen.dart L557-568](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart#L557-L568)
- **User action**: Same as Issue 20 but for image-scanned meals
- **What happens**:
```dart
ElevatedButton(
    onPressed: () async {
        Navigator.of(dialogContext).pop();
        await _saveMealLog(data, selectedMealType, selectedFamilyMemberId);
    },
    // No guard — Navigator.pop happens immediately, _saveMealLog continues
```
The `Navigator.pop` closes the dialog first, but `_saveMealLog` runs after. If the user tapped twice fast enough before `pop` processes, two `_saveMealLog` calls fire.
- **Bad outcome**: Duplicate meal entry.
- **Severity**: **Medium**
- **Fix**: Add loading state to the dialog's StatefulBuilder. Disable the button after first tap.

---

### Issue 22: App killed mid-onboarding → state completely lost, no persistence

- **Where**: [onboarding_view.dart L19-36](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/onboarding/onboarding_view.dart#L19-L36)
- **User action**: User completes 5/7 onboarding pages → app killed → reopens → sent back to page 1
- **What happens**: All state is stored in local `_State` variables:
```dart
String? _goal;
String? _gender;
double _age = 25;
double _heightCm = 170;
double _weightKg = 70;
// No SharedPreferences persistence
```
- **Bad outcome**: User has to redo entire onboarding. Frustrating UX on first launch.
- **Severity**: **Low** (annoyance, not safety)
- **Fix**: Save onboarding progress to SharedPreferences on each page transition.

---

## Category 7: Auth / Data Persistence

### Issue 23: No token expiry handling — Supabase session expires, all API calls fail silently

- **Where**: [main.dart L134-150](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/main.dart#L134-L150) — auth listener only handles `signedIn` and `passwordRecovery`
- **User action**: User leaves app open for hours → Supabase JWT expires → user tries to log a meal
- **What happens**:
```dart
void _initAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn && session != null) {
            // Navigate to main
        } else if (event == AuthChangeEvent.passwordRecovery) {
            // Handle password recovery
        }
        // NO handler for tokenRefreshed, signedOut, or session expired
    });
}
```
Supabase Flutter SDK auto-refreshes tokens, but if the refresh fails (network issue during refresh), `signedOut` fires and there's no handler to redirect to login. The user stays on the dashboard but all Supabase calls fail.
- **Bad outcome**: User taps "Log Meal" → Supabase insert fails → error toast → user confused. No automatic redirect to login.
- **Severity**: **Medium**
- **Fix**: Add handler for `AuthChangeEvent.signedOut` that redirects to the login screen with a message.

---

### Issue 24: Meal scan logs directly to Supabase (not offline cache) — data lost if network drops during save

- **Where**: [scan_meal_screen.dart L601-618](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart#L601-L618) and [barcode_scanner_screen.dart L346-359](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/barcode_scanner_screen.dart#L346-L359)
- **User action**: User scans a meal → confirms → network drops during the Supabase insert
- **What happens**:
```dart
// scan_meal_screen.dart L618
await supabase.from('meal_logs').insert(payload);  // Direct Supabase, no offline cache
```
Compare to ManualLogScreen at [L153-166](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart#L153-L166) which correctly uses `OfflineCache.instance.insertPendingMeal()`.
- **Bad outcome**: User goes through the entire scan → AI analysis → review → confirm flow, only to get "Failed to save meal" and lose everything.
- **Severity**: **Medium**
- **Fix**: Use the same OfflineCache + SyncService pattern that ManualLogScreen uses.

---

## Category 8: Android-Specific

### Issue 25: SQLite module-level connection with `check_same_thread=False` — potential corruption under load

- **Where**: [food_db_service.py L18-29](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/food_db_service.py#L18-L29)
- **What happens**:
```python
_conn: Optional[sqlite3.Connection] = None

def _get_conn() -> Optional[sqlite3.Connection]:
    global _conn
    if _conn is None:
        _conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    return _conn
```
FastAPI uses async workers. Multiple concurrent requests can write to the same SQLite connection simultaneously without synchronization. `cache_food` calls `INSERT OR REPLACE` + `commit()` — two concurrent commits on the same connection can corrupt data.
- **Bad outcome**: Database corruption under concurrent barcode scan requests.
- **Severity**: **Medium** (unlikely at hackathon scale, but real in production)
- **Fix**: Use a threading lock around all DB operations, or use a connection pool, or open a new connection per request.

---

### Issue 26: GeminiPool key rotation not thread-safe — `_current_index` race condition

- **Where**: [gemini_pool.py L53-79](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/gemini_pool.py#L53-L79)
- **What happens**:
```python
for attempt in range(attempts):
    with self._lock:
        idx = self._current_index   # Read under lock
    # ... but the API call happens OUTSIDE the lock
    # Another thread could rotate the index between read and use
    try:
        client = self._get_client(idx)
        response = client.models.generate_content(...)
    except Exception as e:
        with self._lock:
            self._current_index = (self._current_index + 1) % total_keys
```
Two concurrent requests both see `idx=0`, both fail, both increment → index jumps by 2, skipping a key.
- **Bad outcome**: Under concurrent load, keys get skipped in rotation. Not critical but wastes quota on already-exhausted keys.
- **Severity**: **Low**

---

## Category 9: Barcode

### Issue 27: Barcode scan logs to Supabase directly without offline cache (inconsistent with manual log)

- **Where**: [barcode_scanner_screen.dart L346-366](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/barcode_scanner_screen.dart#L346-L366)
- **User action**: User scans barcode → product identified → taps "Confirm & Log" → network drops
- **What happens**: Same as Issue 24. Direct Supabase insert without OfflineCache:
```dart
await Supabase.instance.client.from('meal_logs').insert({
    'user_id': user.id,
    // ...
});
```
- **Bad outcome**: Scanned food lost. User doesn't know if it was saved.
- **Severity**: **Medium**
- **Fix**: Route through OfflineCache like ManualLogScreen.

---

## Category 10: Family Profiles

### Issue 28: Family member meals logged to same user_id — NO backend isolation between family members

- **Where**: [scan_meal_screen.dart L601-618](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/scan_meal_screen.dart#L601-L618) vs [dashboard_screen.dart L142-148](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart#L142-L148)
- **User action**: User switches to "Child (Ahmed)" profile → scans and logs a meal → switches back to "Me (Self)" → checks dashboard
- **What happens**: The dashboard correctly filters meals by `family_member_id`:
```dart
// dashboard_screen.dart L142-148
for (var meal in mealsRes) {
    final fId = meal['family_member_id']?.toString();
    if (activeMember != null) {
        if (fId != activeMember.id) continue;  // Filter for this member
    } else {
        if (fId != null && fId.isNotEmpty) continue;  // Filter out family meals
    }
```
BUT: The **AI Coach chat** (`_sendMessage` in [ai_coach_screen.dart L350](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/chat/ai_coach_screen.dart#L350)) always sends the **primary user's** `user_id` — it does NOT send the active family member's context. The **risk evaluator** also only evaluates the primary user's medical conditions.
- **Bad outcome**: Parent switches to diabetic child's profile → asks AI coach "What should Ahmed eat for lunch?" → coach responds based on the PARENT's health profile (who may not be diabetic) → gives advice that's dangerous for the diabetic child.
- **Severity**: **High** — safety-critical when family member has different medical conditions than primary user.
- **Fix**: When `FamilyViewModel.instance.activeMember != null`, the coach endpoint should receive the family member's medical conditions and targets, not just the primary user's profile. Add `family_member_id` to the `/coach/chat` request.

---

### Issue 29: Family member age/calorie target accepts negative and absurd values

- **Where**: [family_view.dart L228-243](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_view.dart#L228-L243) and [family_view.dart L411-416](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_view.dart#L411-L416)
- **User action**: User adds a family member → types age "-5" or "200" → types calories "99999" or "0"
- **What happens**:
```dart
// family_view.dart L228-230
TextField(
    controller: ageController,
    keyboardType: TextInputType.number,  // Hint only, NOT validation
    // No inputFormatters, no min/max, no validator
```
```dart
// family_view.dart L423
age: int.tryParse(ageController.text) ?? 25,  // Fallback to 25 on parse fail
dailyCalorieTarget: int.tryParse(calController.text) ?? 1800,  // No range check
```
- **Bad outcome**: A family member with age=-5 gets child calorie recommendations via `calculateRecommendedTargets` which would use the default 1800kcal branch. A child with 99999 kcal target would never trigger any overshoot warning. Calorie target of 0 makes all meals 100%+ overshoot.
- **Severity**: **Medium**
- **Fix**: Add `inputFormatters: [FilteringTextInputFormatter.digitsOnly]` and range validators. Clamp age to 0-120, calories to 500-5000.

---

### Issue 30: Local-only family members never sync to Supabase — lost on reinstall

- **Where**: [family_viewmodel.dart L115-127](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_viewmodel.dart#L115-L127)
- **User action**: User adds family member while offline → app creates `local_` prefixed member → user goes online → never synced
- **What happens**:
```dart
} catch (e) {
    // If table doesn't exist yet on remote or offline, save locally
    final localMember = member.copyWith(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
    );
    _members = [..._members, localMember];
    await _saveToLocalCache();  // SharedPreferences only
    return true;  // Returns success!
}
```
There's NO retry mechanism. When `loadMembers` is called again later, it fetches from Supabase and overwrites the local cache at [L72-73](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_viewmodel.dart#L72-L73):
```dart
_members = loaded;
await _saveToLocalCache();  // Overwrites local-only members!
```
- **Bad outcome**: User adds family member offline → goes online → opens Family Profiles → local member is silently deleted when Supabase fetch overwrites the cache.
- **Severity**: **Medium**
- **Fix**: Before overwriting local cache on Supabase success, check for `local_` prefixed members in the existing list and attempt to push them to Supabase. Or merge the two lists.

---

### Issue 31: Deleting active family member leaves dashboard showing stale data until next reload

- **Where**: [family_viewmodel.dart L166-193](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/family_profiles/family_viewmodel.dart#L166-L193)
- **User action**: User has "Ahmed" as active profile → deletes Ahmed → goes back to Dashboard
- **What happens**:
```dart
if (_activeMember?.id == memberId) {
    _activeMember = null;  // Reset to primary
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeMemberKey);
}
```
This correctly resets `_activeMember` to null. BUT the dashboard listener `_loadData` is called via `notifyListeners()`, which triggers a full data reload. However, the Dashboard still holds the old `_targetCalories` etc. from Ahmed's profile until `setState` runs. If `_loadData` fails (network), the dashboard shows Ahmed's targets with "Me" label.
- **Bad outcome**: Mild UX confusion. Stale targets shown briefly.
- **Severity**: **Low**

---

## Category 11: Profile Settings

### Issue 32: Settings saves profile without recalculating calorie/macro targets — user updates weight/goal but targets stay stale

- **Where**: [settings_view.dart L119-166](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart#L119-L166)
- **User action**: User changes weight from 70kg to 90kg, goal from "fat_loss" to "muscle_gain" → taps "Save Targets"
- **What happens**:
```dart
final payload = {
    'age': int.parse(_ageController.text),
    'weight_kg': double.parse(_weightController.text),
    'height_cm': double.parse(_heightController.text),
    // ...
    'goal': _goal,
    'activity_level': _activityLevel,
};
await supabase.from('health_profiles').update(payload).eq('user_id', user.id);
```
The settings screen updates raw profile fields (weight, goal) but **does NOT recalculate** `daily_calorie_target`, `daily_protein_g`, `daily_carbs_g`, `daily_fat_g`. Those fields in the DB are only calculated once during onboarding at [health_profile.py L24-40](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/health_profile.py#L24-L40). The settings update does NOT call the onboarding endpoint — it directly updates the raw DB.
- **Bad outcome**: User changed their weight from 70→90kg and goal from fat_loss→muscle_gain. But their daily calorie target stays at the old value (e.g., 1400 kcal for fat loss at 70kg) instead of being recalculated to ~2800 kcal for bulking at 90kg. Dashboard shows wrong targets. All compliance metrics (habit score, weekly report adherence) are based on stale targets.
- **Severity**: **High** — fundamentally breaks the core tracking logic.
- **Fix**: Either call the onboarding recalculation endpoint from settings, or add BMR recalculation logic to the settings save flow. At minimum, recalculate on the backend when weight/height/goal/activity changes.

---

### Issue 33: Settings age/weight/height/budget accept non-numeric and negative input — FormatException crash

- **Where**: [settings_view.dart L139-142](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart#L139-L142)
- **User action**: User types "abc" in the age field → taps "Save Targets"
- **What happens**:
```dart
'age': int.parse(_ageController.text),        // FormatException!
'weight_kg': double.parse(_weightController.text),  // FormatException!
```
The form validator only checks for empty (`val == null || val.isEmpty`), NOT for numeric validity. `int.parse("abc")` throws `FormatException` which is caught by the outer catch but shows raw error: `"Save failed: FormatException: Invalid radix-10 number"`.
- **Bad outcome**: Confusing error message. If user types "-5" for age, `int.parse("-5")` succeeds and saves negative age to the DB.
- **Severity**: **Medium**
- **Fix**: Add numeric validators: `validator: (val) { if (val == null || val.isEmpty) return 'Required'; if (int.tryParse(val) == null) return 'Enter a valid number'; return null; }`

---

### Issue 34: Delete account endpoint has NO authentication — any HTTP client can delete any user

- **Where**: [profile.py L10-19](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/profile.py#L10-L19)
- **User action**: Attacker sends `POST /api/v1/profile/delete-account` with body `{"user_id": "target-uuid"}`
- **What happens**:
```python
@router.post("/delete-account")
def delete_user_account(data: DeleteAccountRequest):
    supabase = get_supabase_admin_client()
    supabase.auth.admin.delete_user(data.user_id)  # Admin delete, no auth check!
```
No JWT validation, no auth middleware, no comparison of `data.user_id` against the authenticated session. Uses `admin_client` which has full power.
- **Bad outcome**: If the backend is ever exposed publicly (e.g., via ngrok for demo), any user can delete any other user's entire account and data.
- **Severity**: **High** (medium for hackathon-local only, but critical for any production deployment)
- **Fix**: Add auth dependency: verify the JWT from the request header, compare `request_user_id == data.user_id`, reject if mismatched.

---

## Category 12: Ramadan Mode

### Issue 35: Ramadan mode Sehri time set AFTER Iftar time — fasting logic inverts, progress shows wrong

- **Where**: [ramadan_controller.dart L109-116](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/ramadan_controller.dart#L109-L116)
- **User action**: User sets Suhoor to 19:00 and Iftar to 04:00 (accidentally swapped)
- **What happens**:
```dart
bool isCurrentlyFasting() {
    final suhoorMinutes = _suhoorTime.hour * 60 + _suhoorTime.minute;  // 1140
    final iftarMinutes = _iftarTime.hour * 60 + _iftarTime.minute;      // 240
    final currentMinutes = now.hour * 60 + now.minute;

    return currentMinutes >= suhoorMinutes && currentMinutes < iftarMinutes;
    // 1140 >= 1140 && 1140 < 240 → FALSE (because 1140 < 240 is false)
    // This means the user is NEVER fasting — function always returns false
}
```
```dart
double getFastingProgress() {
    final totalFastDuration = iftarMinutes - suhoorMinutes; // 240 - 1140 = -900
    if (totalFastDuration <= 0) return 0.5;  // Hardcoded fallback — wrong!
}
```
- **Bad outcome**: Fasting progress bar always shows 50%. "Eating window" status message shown during actual fasting time. Sehri/Iftar notifications fire at wrong times.
- **Severity**: **Medium**
- **Fix**: Validate at save time: `if (suhoorTime.hour * 60 + suhoorTime.minute >= iftarTime.hour * 60 + iftarTime.minute)` → show toast "Sehri must be before Iftar" and reject. Or handle overnight fasting logic properly.

---

### Issue 36: Ramadan timezone hardcoded to 'Asia/Karachi' — wrong for non-PKT users

- **Where**: [reminder_manager.dart L42](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/reminder_manager.dart#L42)
- **User action**: A user in Dubai (UTC+4) enables Ramadan mode and sets Iftar at 6:45 PM local time
- **What happens**:
```dart
try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));  // PKT = UTC+5 hardcoded!
} catch (_) {}
```
All scheduled notifications use `tz.local` which is locked to `Asia/Karachi`. For a user in Dubai (UTC+4), the Sehri notification fires 1 hour late. For a user in the UK (UTC+0/+1), it fires 4-5 hours late.
- **Bad outcome**: Ramadan notifications (Sehri ending, Iftar) fire at wrong times. User misses Sehri deadline or gets Iftar notification an hour late.
- **Severity**: **Medium** (if targeting only Pakistani users, Low)
- **Fix**: Use `tz.setLocalLocation(tz.getLocation(Platform.localeName))` or detect timezone from the device. At minimum, make the timezone configurable.

---

### Issue 37: Disabling Risk Alerts in settings lets user silence ALL safety notifications

- **Where**: [settings_view.dart L1067-1074](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/settings/settings_view.dart#L1067-L1074) → [reminder_manager.dart L402-429](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/reminder_manager.dart#L402-L429)
- **User action**: Diabetic user toggles "AI Clinical Safety Alerts" OFF in settings → asks coach "My blood sugar is 350, what should I do?"
- **What happens**:
```dart
// settings_view.dart L1070-1073
onChanged: (val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ReminderManager.keyRiskAlerts, val);
    setState(() => _riskAlerts = val);
},
```
```dart
// reminder_manager.dart L407-409
static Future<void> showRiskAlert({...}) async {
    final enabled = prefs.getBool(keyRiskAlerts) ?? true;
    if (!enabled) return;  // ← Safety notification silently suppressed
```
The escalation still triggers in the chat (the in-chat banner is separate), BUT the system notification is suppressed. If the user is not looking at the chat screen (e.g., they sent the message and backgrounded the app), they miss the critical alert entirely.
- **Bad outcome**: At-risk user explicitly disabled safety alerts → gets no notification for critical health risk → no clinic finder prompt.
- **Severity**: **High** — users should not be able to disable life-safety notifications.
- **Fix**: For `critical` level alerts, ALWAYS fire the notification regardless of user preference. The setting should only control `warning` level alerts. Show a disclaimer when disabling: "Critical safety alerts will still be shown."

---

## Category 13: Swap Foods

### Issue 38: Swap food suggestions fire silently in background — toast may not show if screen transitions

- **Where**: [swap_service.dart L32-49](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/swap_service.dart#L32-L49)
- **User action**: User logs a meal → SwapService.checkMealForSwaps runs in background → user navigates to different screen before swap response arrives
- **What happens**:
```dart
final context = globalNavigatorKey.currentContext;
if (swaps.isNotEmpty && context != null && context.mounted) {
    CustomToast.show(
        context,
        'Healthier alternatives found for your recent meal! Tap to view.',
        onTap: () {
            MainNavigationScreen.of(context).currentIndex = 3;  // Switch to settings tab
```
The `globalNavigatorKey.currentContext` may point to a context that's no longer visible. The `onTap` navigates to tab index 3 (Settings), but the swap cards are actually displayed on the Dashboard tab.
- **Bad outcome**: Toast fires on a screen where it might be obscured. The "Tap to view" action sends user to Settings instead of Dashboard where the swap cards appear. User never sees the swap suggestions.
- **Severity**: **Low**
- **Fix**: Use a persistent notification or in-app message queue instead of a toast. Fix the tab index to navigate to the correct screen where swaps are displayed.

---

### Issue 39: Swap food API failure silently swallowed — no fallback, no user feedback

- **Where**: [swap_service.dart L52-54](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/swap_service.dart#L52-L54) and [gemini_service.py L365-366](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/gemini_service.py#L365-L366)
- **User action**: User logs a meal → Gemini is rate-limited → swap generation fails
- **What happens**:
```python
# Backend gemini_service.py L365-366
except Exception:
    return []  # Empty swaps, no error info

# Frontend swap_service.dart L52-54
} catch (e) {
    debugPrint('Error in SwapService background check: $e');  // Silent
}
```
- **Bad outcome**: User never gets swap suggestions when AI is down. Acceptable behavior for a non-critical feature, but the user has no idea swaps even exist as a feature if they never fire.
- **Severity**: **Low** — checked, acceptable for non-critical feature.

---

## Category 14: Smart Alerts / Notifications

### Issue 40: All streak/meal notifications use same fixed ID — only last scheduled one survives

- **Where**: [reminder_manager.dart L138-201](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/reminder_manager.dart#L138-L201)
- **Traced code**: Checked, IDs are unique per notification type (breakfast=1, lunch=2, dinner=3, hydration=10-13, ramadan=101-104, streak=201-202, risk=301). **No issue found** — IDs are correctly distributed.

---

### Issue 41: Streak milestone notification always uses same ID 201 — rapid milestone events overwrite each other

- **Where**: [reminder_manager.dart L354](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/reminder_manager.dart#L354)
- **What happens**:
```dart
await _notifications.show(
    id: 201,  // Same ID for ALL milestones
    title: title,
```
If a user logs meals rapidly and hits streak 3 and 5 in the same session, the notification for streak 3 is immediately replaced by streak 5.
- **Bad outcome**: User misses intermediate streak celebration. Minor UX issue.
- **Severity**: **Low** — checked, acceptable behavior.

---

## Category 15: Grocery List

### Issue 42: Grocery list not generated when no meals logged — confusing empty state

- **Where**: [grocery_viewmodel.dart L49-78](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/grocery_list/grocery_viewmodel.dart#L49-L78) → [meals.py L297-323](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/meals.py#L297-L323)
- **User action**: New user with no meals logged → opens Grocery List → taps "Generate List"
- **What happens**: The backend fetches last 30 days of meals → finds 0 → sends empty `recent_meals` list to Gemini. Gemini generates a generic grocery list that has no personalization.
- **Bad outcome**: Not a bug per se, but the generated list won't reflect user's actual eating patterns since there are none. The empty state message says "analyze your targets & recent meals" which is misleading when there are no recent meals.
- **Severity**: **Low** — checked, acceptable behavior. Could improve empty state messaging.

---

## Category 16: Weekly Report

### Issue 43: Report reads `protein_g` from meal_logs but meals are stored as `total_protein_g` — protein always 0 in reports

- **Where**: [report_service.py L67-69](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/report_service.py#L67-L69)
- **User action**: User opens weekly report after logging meals all week
- **What happens**:
```python
# report_service.py L67-69
prot = int(m.get('protein_g') or 0)    # WRONG KEY
carbs = int(m.get('carbs_g') or 0)     # WRONG KEY
fat = int(m.get('fat_g') or 0)         # WRONG KEY
```
But the scan_meal_screen logs meals with `total_protein_g`, `total_carbs_g`, `total_fat_g`:
```dart
// scan_meal_screen.dart L608-613
'total_protein_g': totalProtein,
'total_carbs_g': totalCarbs,
'total_fat_g': totalFat,
```
And the manual_log_screen also uses `total_protein_g` at [L161](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/meal_scan/manual_log_screen.dart#L161).
- **Bad outcome**: Weekly report shows 0g protein, 0g carbs, 0g fat for ALL meals. Only calories (which correctly uses `total_calories`) shows accurate data. The health score and compliance metrics for macros are wrong.
- **Severity**: **High** — the weekly report's macro data is completely broken.
- **Fix**:
```diff
# report_service.py L67-69
-prot = int(m.get('protein_g') or 0)
-carbs = int(m.get('carbs_g') or 0)
-fat = int(m.get('fat_g') or 0)
+prot = int(m.get('total_protein_g') or m.get('protein_g') or 0)
+carbs = int(m.get('total_carbs_g') or m.get('carbs_g') or 0)
+fat = int(m.get('total_fat_g') or m.get('fat_g') or 0)
```

---

### Issue 44: Backend PDF report strips all Urdu text — user gets blank spaces instead of AI summary

- **Where**: [report_service.py L266-268](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/services/report_service.py#L266-L268)
- **User action**: Urdu-language user generates PDF weekly report
- **What happens**:
```python
safe_summary_clean = ''.join(c if ord(c) < 128 else ' ' for c in safe_summary)
```
ALL non-ASCII characters are replaced with spaces. The Gemini AI summary was generated in Urdu (as requested at L204), but the PDF rendering strips it entirely.
- **Bad outcome**: Urdu users get a PDF with the entire AI Clinical Review section as blank whitespace. The numerical stats are fine (ASCII), but the personalized coaching narrative is gone.
- **Severity**: **Medium**
- **Fix**: Use a PDF library that supports Unicode fonts (e.g., embed a TTF font like NotoSansArabic) or generate the PDF narrative in English regardless of language setting, with a note that the full Urdu summary is available in-app.

---

## Category 17: Dashboard

### Issue 45: Dashboard queries meals by UTC dates — misses meals logged near midnight in PKT (UTC+5)

- **Where**: [dashboard_screen.dart L125-128](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart#L125-L128)
- **User action**: User in Pakistan logs a meal at 11:30 PM PKT (= 6:30 PM UTC). Next day, opens dashboard at 1:00 AM PKT (= 8:00 PM previous day UTC).
- **What happens**:
```dart
final now = DateTime.now();  // Local time
final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc().toIso8601String();
```
At 1:00 AM PKT on Aug 25:
- `startOfDay` = Aug 24, 19:00 UTC (correct — it's still Aug 24 in UTC)
- `endOfDay` = Aug 25, 18:59 UTC
- Meal logged at 11:30 PM PKT on Aug 24 = 6:30 PM UTC on Aug 24 → this is BEFORE `startOfDay` (7:00 PM UTC Aug 24)

Wait — let me recalculate. At 1:00 AM PKT Aug 25: `DateTime(2025, 8, 25).toUtc()` = Aug 24 19:00 UTC. The meal was logged at 11:30 PM PKT Aug 24 = Aug 24 18:30 UTC. **18:30 < 19:00** → the meal falls OUTSIDE the query range.
- **Bad outcome**: Meals logged between 12:00 AM - 12:30 AM PKT are double-counted (appear in both "today" for Aug 24 local and Aug 25 local). Meals logged in the PKT-day-ahead-of-UTC window get missed.

Actually, the core issue is: the code converts **local** midnight to UTC, which is correct for querying Supabase TIMESTAMPTZ. But if Supabase stores `logged_at` as UTC, then a meal logged at 11:30 PM PKT = 6:30 PM UTC falls within Aug 24 UTC 19:00 to Aug 25 UTC 18:59, which is the correct "local Aug 25" range. Let me re-verify...

Actually, `DateTime(now.year, now.month, now.day)` at 1:00 AM PKT Aug 25 creates `2025-08-25 00:00:00 PKT`. `.toUtc()` converts to `2025-08-24 19:00:00Z`. A meal at 11:30 PM PKT Aug 24 = `2025-08-24 18:30:00Z`. This is BEFORE `startOfDay` = `2025-08-24 19:00:00Z`. So the meal is **missed from "today's" (Aug 25) dashboard** even though the user logged it on their Aug 24.

The real bug: The user expects "today's meals" on Aug 25 to include only Aug 25 meals, but the previous day's late-night meals (11:30 PM PKT Aug 24) are neither in Aug 24's range (if they reload) nor Aug 25's range.
- **Severity**: **Medium** — meals near midnight boundary get lost from the daily view.
- **Fix**: Use local date boundaries consistently, or use `gte('logged_at', startOfDayLocal)` where the local date boundary is sent as an offset parameter.

---

## Category 18: Coaching / Habit Score

### Issue 46: Habit score endpoint exposes ALL user data via user_id in URL — no auth check

- **Where**: [coaching.py L14](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/backend/app/api/v1/endpoints/coaching.py#L14)
- **User action**: Attacker calls `GET /api/v1/coaching/habit-score/{any_user_id}`
- **What happens**:
```python
@router.get("/habit-score/{user_id}")
def get_habit_score(user_id: str, offset_minutes: int = 0):
    # No auth check — returns full profile + 30 days of meal data
```
- **Bad outcome**: If backend is exposed, anyone can query any user's health profile, meal logs, and habit scores.
- **Severity**: **Medium** (hackathon) / **Critical** (production)
- **Fix**: Add JWT auth middleware and verify `user_id` matches the authenticated session.

---

## Checked — No Issue Found

### Ramadan Fasting Logic
- [ramadan_controller.dart L109-132](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/ramadan_controller.dart#L109-L132): `isCurrentlyFasting()`, `getFastingProgress()`, `getTimeUntilNextEvent()` — **checked, logic is correct** for normal suhoor-before-iftar cases. Edge case of swapped times covered in Issue #35.

### Ramadan Meal Name Mapping
- [ramadan_controller.dart L183-211](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/ramadan_controller.dart#L183-L211): Mapping breakfast→Sehri, dinner→Iftar, etc. — **checked, correct and localized.**

### Water Logging (Dashboard)
- [dashboard_screen.dart L239-262](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/dashboard/dashboard_screen.dart#L239-L262): Uses OfflineCache properly (unlike scan/barcode). **Checked, correct.**

### Update Password Flow
- [update_password_screen.dart](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/auth/update_password_screen.dart): Validates min length 8, confirm match, uses Supabase `updateUser`. **Checked, no issue found.**

### Auth Login/Signup Flow
- [auth_view.dart L43-97](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/auth/auth_view.dart#L43-L97): Checks for existing profile → routes to onboarding or main. **Checked, correct flow.**

### Grocery List Local Cache
- [grocery_viewmodel.dart L23-47](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/ui/features/grocery_list/grocery_viewmodel.dart#L23-L47): Caches to SharedPreferences, loads on init. **Checked, correct.**

### Family Profile Auto-Calculation
- [family_member.dart L91-146](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/data/models/family_member.dart#L91-L146): Age/gender/condition-aware calorie targets. **Checked, logic is reasonable and condition-adjusted.**

### Adaptive Meal Reminders
- [reminder_manager.dart L117-232](file:///d:/mobileAppDev/BanoQabilHackathon/NutriSense/frontend/lib/core/reminder_manager.dart#L117-L232): Learns average meal times via exponential moving average. **Checked, clever and correct.**

---

## Prioritized Fix List (Complete — 46 Issues)

### 🔴 Non-Negotiable — Fix First (Could Harm At-Risk Users)

| Priority | Issue | Title | Severity |
|----------|-------|-------|----------|
| **P0** | #8 | Risk evaluator misses hypoglycemia (low blood sugar values not in keyword list) | Critical |
| **P0** | #9 | Risk evaluator Gemini failure silently drops escalation for users with conditions | Critical |
| **P0** | #1 | `estimate_food_macros` returns fake data silently — corrupts all downstream safety | Critical |
| **P0** | #37 | User can silence ALL safety notifications including critical escalation alerts | High |
| **P1** | #2 | Frontend doubles down on fake macros when offline | Critical |
| **P1** | #28 | AI Coach uses parent's profile when family member with different conditions is active | High |
| **P1** | #10 | Critical escalation alert only as notification — not blocking UI | High |
| **P1** | #14 | Coach contradicts escalation — "you're fine" vs. "danger" | High |
| **P1** | #11 | Clinic finder shows wrong-city clinics to all non-Karachi/Lahore users | High |
| **P1** | #12 | Overpass zero results → falls back to wrong city | High |
| **P1** | #4 | USDA failure → zeros logged as real meal data | High |

### 🟡 High Priority — Fix Next (Reliability / Data Integrity)

| Priority | Issue | Title | Severity |
|----------|-------|-------|----------|
| **P2** | #32 | Settings saves profile without recalculating calorie targets | High |
| **P2** | #43 | Report reads `protein_g` instead of `total_protein_g` — macros always 0 in reports | High |
| **P2** | #34 | Delete account endpoint has no authentication | High |
| **P2** | #3 | No timeout on coach chat HTTP call — infinite "Typing..." | High |
| **P2** | #5 | Onboarding accepts weight=0, height=0, age=0 | High |
| **P2** | #20 | Double-tap "Confirm & Log" in barcode → duplicate entry | Medium |
| **P2** | #21 | Double-tap "Confirm & Log" in scan meal → duplicate entry | Medium |
| **P2** | #24 | Scan meal saves directly to Supabase, not offline cache | Medium |
| **P2** | #27 | Barcode scan saves directly to Supabase, not offline cache | Medium |
| **P2** | #23 | No token expiry/signedOut handler | Medium |
| **P2** | #17 | Voice mode double submission | Medium |
| **P2** | #13 | Race condition: navigate away during escalation | Medium |
| **P2** | #15 | Chat history truncation loses safety context | Medium |
| **P2** | #30 | Local-only family members overwritten on next Supabase fetch | Medium |
| **P2** | #35 | Ramadan sehri/iftar swapped → fasting logic inverts | Medium |
| **P2** | #45 | Dashboard UTC date boundary misses late-night meals | Medium |

### 🟢 UX Polish — Fix When Possible

| Priority | Issue | Title | Severity |
|----------|-------|-------|----------|
| **P3** | #6 | No input length limit on coach messages | Medium |
| **P3** | #7 | Barcode input accepts non-numeric strings | Medium |
| **P3** | #25 | SQLite concurrent access on backend | Medium |
| **P3** | #29 | Family member age/calorie accepts absurd values | Medium |
| **P3** | #33 | Settings age/weight accept non-numeric — FormatException | Medium |
| **P3** | #36 | Ramadan timezone hardcoded to Asia/Karachi | Medium |
| **P3** | #44 | PDF report strips all Urdu text | Medium |
| **P3** | #46 | Habit score endpoint has no auth | Medium |
| **P3** | #16 | Raw error messages shown to user | Low |
| **P3** | #22 | Onboarding state lost on kill | Low |
| **P3** | #26 | GeminiPool key rotation race | Low |
| **P3** | #31 | Deleting active family member shows stale dashboard | Low |
| **P3** | #38 | Swap toast navigates to wrong tab | Low |
| **P3** | #39 | Swap API failure silently swallowed | Low |
| **P3** | #41 | Streak milestone notifications overwrite each other | Low |
| **P3** | #42 | Grocery list not personalized when no meals logged | Low |
