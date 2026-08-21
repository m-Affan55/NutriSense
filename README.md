# NutriSense - AI-Powered Nutrition & Coaching Platform

NutriSense is a comprehensive health and nutrition manager featuring AI-powered coaching, macro estimations from meal text/photos, custom local notifications, offline database synchronization, bilingual (English/Urdu) localization, and automated smart grocery lists.

---

## Project Structure

```text
NutriSense/
├── backend/            # FastAPI backend service
├── frontend/           # Flutter mobile and desktop application
├── supabase/           # Database schema migrations
└── walkthrough.md      # Summary of feature implementations
```

---

## Backend Setup (FastAPI)

The backend utilizes FastAPI to handle estimation prompts via the Gemini API, communicate with the Supabase Postgres DB, and serve nutritional stats.

### Prerequisites
* Python 3.10 or higher installed.

### Setup Steps
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a Python virtual environment:
   ```bash
   python -m venv venv
   # On Windows:
   .\venv\Scripts\activate
   # On macOS/Linux:
   source venv/bin/activate
   ```
3. Install the dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file in the `backend/` directory:
   ```env
   SUPABASE_URL=https://your-supabase-project.supabase.co
   SUPABASE_KEY=your-supabase-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
   GEMINI_API_KEY=your-google-gemini-api-key
   ```
5. Start the local API server:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
   * The API docs will be available locally at: `http://localhost:8000/docs`.

---

## Database Migration (Supabase)

To provision your database schema, apply the DDL instructions located in:
* `supabase/schema.sql`

This initializes tables for:
* `health_profiles` (health metrics, dietary constraints, goals)
* `meal_logs` (notes, calories, protein, carbs, fats, sync indicators)
* `hydration_logs` (water intake logs, timestamp, sync indicators)

---

## Frontend Setup (Flutter)

The frontend is built with Flutter and supports Android, iOS, and Windows desktop.

### Prerequisites
* Flutter SDK (v3.24+ recommended) configured on your system PATH.
* For Windows Desktop builds: Visual Studio with "Desktop development with C++" workload installed.

### Setup Steps
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Fetch package dependencies:
   ```bash
   flutter pub get
   ```
3. Create a `.env` file in the `frontend/` directory:
   ```env
   SUPABASE_URL=https://your-supabase-project.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   BACKEND_URL=http://localhost:8000/api/v1
   ```
   *(Note: When testing on a physical Android device, replace `localhost` with your machine's local IP address, e.g. `http://192.168.1.50:8000/api/v1`)*.
4. Run the application:
   ```bash
   # Detect and run on active device/emulator
   flutter run
   ```

---

## Troubleshooting Guide

### 1. Windows path spacing compilation bug (`%20`)
If your Windows username contains spaces (e.g. `C:\Users\John Doe\`), the Dart compilation agent may throw an `Error when reading... file not found` due to URL-encoded path resolution bugs.

* **Workaround**:
  1. Open Windows **System Properties -> Environment Variables -> User Variables**.
  2. Add a new variable:
     * **Variable name**: `PUB_CACHE`
     * **Variable value**: `C:\pub_cache` *(Forces the package downloader to use a folder without spaces)*.
  3. Restart your terminal or IDE, and run `flutter pub get`.

### 2. Social Login / Password Recovery Redirects
For Supabase authentication redirects to return users back to the Flutter app after Google authentication or password resets:
* Add `io.supabase.nutrisense://**` inside **Supabase Dashboard -> Authentication -> Redirect URLs**.
