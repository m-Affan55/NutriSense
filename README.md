# AI Nutrition Coach

A Vision-Powered Personal Nutritionist, built for the BanoQabil Hackathon.

## Overview
This application shifts the paradigm from a traditional calorie tracker to a proactive, intelligent nutrition coach. Instead of manually logging food, users can simply take a photo of their meal, and the AI handles the understanding, logging, and personalized feedback.

## Key Features

### Core Functionality
*   **Conversational Onboarding:** A chatbot-style interface to gather user profile data (goals, activity level, dietary restrictions, budget) instead of static forms.
*   **Personalized Diet Plan:** Custom daily plans covering meals, water intake, calories, and macros tailored to the user's specific goals.
*   **Meal Photo Recognition:** The centerpiece feature. Users photograph their plate, and the app identifies food items, estimates macros/calories, and logs the meal automatically.
*   **AI Nutrition Chat:** A specialized assistant that can answer context-aware questions (e.g., "Suggest a high-protein breakfast with eggs and bread") and adapt to user constraints.
*   **Daily Progress Dashboard:** A single unified view of calories, macros, hydration, and other health metrics.
*   **AI Weekly Report:** Intelligent, narrative summaries of the user's week (e.g., "You consumed 18% more sugar this week") rather than just numerical charts.

### Standout Differentiators (Planned)
*   **Predictive Coaching:** Proactive suggestions to prevent bad habits before they happen (e.g., "You usually exceed your calorie target on Fridays; here are healthy dinner options to try.").
*   **Food Swap AI:** Upload a photo of a high-calorie meal, and the AI suggests a macro-equivalent healthier alternative.

## Tech Stack
*   **Frontend:** Flutter (Mobile App)
*   **Backend:** FastAPI (Python)
*   **Database:** SupaBase
*   **AI & Computer Vision:** Gemini / OpenAI
