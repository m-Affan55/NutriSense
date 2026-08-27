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

- **Category 11: Profile Settings [Resolved ✅]**
  - **Issue 33 [Resolved ✅]**: Restricts settings inputs (age, weight, height, budget) to clean numeric ranges, prevents empty submissions, and ensures that user-friendly messages are displayed instead of raw FormatException compiler details.