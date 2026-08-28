# NutriSense — MVP Resolved Issues Log

This file tracks all resolved categories and issues from the Adversarial QA Audit Report.

---

- **Category 1: Network Failures [Resolved ✅]**
  - Handles API/Gemini timeouts safely (up to 60 seconds) and displays user-friendly connection error dialogs instead of silently logging fabricated mock values.

- **Category 2: Input Validation & Malformed Data [Resolved ✅]**
  - Implements strict validation and constraints on onboarding sliders, AI coach message sizes, and manual barcode input characters to prevent crashes and prompt injections.

- **Category 3: Escalation / Clinic-Finder (Safety-Critical) [Resolved ✅]**
  - Protects at-risk users by detecting hypoglycemia levels (<70 mg/dL), enforcing fail-safe safety warning defaults during API outages, implementing blocking UI alert overlays in the chat screen, and providing direct Google Maps fallback search links when dynamic location services are unavailable.

- **Category 4: AI Coach (Gemini) Reliability [Resolved ✅]**
  - **Issue 14 [Resolved ✅]**: Appends safety disclaimers to the coach's replies when risk warning/escalation levels trigger (`warning`/`critical`), eliminating contradictory advice.
  - **Issue 15 [Resolved ✅]**: Increases the active conversation history window to the last 20 messages. Adds a safety context scanner that extracts clinical triggers (high/low sugar numbers, acute symptoms) from older truncated history messages and prefixes them as system reminders in the message body so safety context is never lost.

- **Category 5: Voice Assistant [Resolved ✅]**
  - **Issue 17 [Resolved ✅]**: Adds a concurrent request guard to `_startListening()` in `ai_coach_screen.dart` to prevent the mic from listening and auto-submitting duplicate messages while the coach is still processing a response.
  - **Issue 18 [Resolved ✅]**: Wraps native platform permission request calls in try-catches to prevent app crashes on unsupported desktop platforms (like Windows/Linux) and fall back gracefully.
  - **Issue 19 [Resolved ✅]**: Utilizes monotonic utterance tokens (`_utterance++`) and stops both local AudioPlayer and FlutterTts streams before starting any new speech, avoiding overlay/interruption issues.

- **Category 11: Profile Settings [Resolved ✅]**
  - **Issue 6 [Resolved ✅]**: Replaced wildcard CORS origins in `main.py` with `allow_origin_regex` to support credentialed browser sessions.
  - **Issue 33 [Resolved ✅]**: Restricts settings inputs (age, weight, height, budget) to clean numeric ranges, prevents empty submissions, and ensures that user-friendly messages are displayed instead of raw FormatException compiler details.
  - **Issue 34 [Resolved ✅]**: Added JWT token validation to account deletion endpoint to verify requesting user identity.

- **Category 8: Android-Specific [Resolved ✅]**
  - **Issue 4 [Resolved ✅]**: Enabled Android launcher icon generation (`android: true`) under `flutter_launcher_icons` in `pubspec.yaml` and generated launcher icon assets for Android, iOS, Web, and Windows.
  - **Issue 5 [Skipped ⚠️]**: Kept `.env` file packaged as a Flutter asset as per user decision.