# 🚀 NutriSense — Complete Deployment & APK Build Guide

This comprehensive guide walks you through:
1. **Hosting the FastAPI Backend** (Free & Fast on Render / Railway).
2. **Configuring Supabase in Production**.
3. **Building the Android APK file (`.apk`)** for live device testing and submission.
4. **Installing the APK on Android Devices**.
5. **(Optional) Hosting the Flutter Web App**.

---

## 📑 Table of Contents
- [Part 1: Hosting the FastAPI Backend (Render)](#part-1-hosting-the-fastapi-backend-on-render)
- [Part 2: Configuring Production Environment Variables](#part-2-configuring-production-environment-variables)
- [Part 3: Building the Android Release APK](#part-3-building-the-android-release-apk)
- [Part 4: Installing the APK on Devices](#part-4-installing-the-apk-on-devices)
- [Part 5: (Bonus) Deploying Flutter Web](#part-5-bonus-deploying-flutter-web)
- [Troubleshooting & Pro Tips](#troubleshooting--pro-tips)

---

## Part 1: Hosting the FastAPI Backend (on Render)

[Render](https://render.com) provides free hosting with automatic HTTPS for FastAPI applications.

### Step 1: Push Your Code to GitHub
1. Make sure your latest backend code is pushed to your GitHub repository:
   ```bash
   git add .
   git commit -m "Prepare NutriSense for deployment"
   git push origin main
   ```

### Step 2: Create a Web Service on Render
1. Go to [dashboard.render.com](https://dashboard.render.com/) and Sign Up / Log In with GitHub.
2. Click **New +** $\to$ Select **Web Service**.
3. Connect your GitHub repository (`NutriSense`).
4. Fill in the deployment details:
   - **Name**: `nutrisense-api` (or any unique name)
   - **Region**: Singapore or Frankfurt (choose closest to Pakistan)
   - **Branch**: `main`
   - **Root Directory**: `backend`
   - **Runtime**: `Python 3`
   - **Build Command**:
     ```bash
     pip install -r requirements.txt
     ```
   - **Start Command**:
     ```bash
     uvicorn app.main:app --host 0.0.0.0 --port $PORT
     ```
   - **Instance Type**: `Free`

### Step 3: Set Backend Environment Variables
Under the **Environment Variables** section on Render, add:
| Key | Value | Notes |
| :--- | :--- | :--- |
| `SUPABASE_URL` | `https://your-project.supabase.co` | From your Supabase Project Settings |
| `SUPABASE_KEY` | `your-supabase-anon-key` | From Supabase API Keys |
| `SUPABASE_SERVICE_ROLE_KEY` | `your-service-role-key` | From Supabase API Keys |
| `GEMINI_API_KEY` | `your-gemini-api-key` | From Google AI Studio |
| `ENVIRONMENT` | `production` | Optional |

### Step 4: Deploy & Copy Backend URL
1. Click **Create Web Service**.
2. Render will build and deploy your API in ~2–3 minutes.
3. Once live, copy your public backend URL, for example:
   ```text
   https://nutrisense-api.onrender.com
   ```
4. Test it in your browser: `https://nutrisense-api.onrender.com/docs` (Interactive Swagger Docs).

---

## Part 2: Configuring Production Environment Variables

Now link your Flutter frontend to your live hosted backend:

1. Open [`frontend/.env`](file:///d:/AI%20Hackathon/NutriSense/frontend/.env) and update the `BACKEND_URL`:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   BACKEND_URL=https://nutrisense-api.onrender.com/api/v1
   ```
   *(Replace `https://nutrisense-api.onrender.com` with your actual live Render URL)*.

2. In Supabase Dashboard:
   - Go to **Authentication** $\to$ **URL Configuration**.
   - Under **Redirect URLs**, make sure `io.supabase.nutrisense://**` is added.

---

## Part 3: Building the Android Release APK

Flutter provides built-in tools to compile optimized, standalone `.apk` files.

### Method A: Single Universal APK (Recommended for Quick Demos & Sharing)
This produces a single `.apk` file that works on **all** Android devices (ARM64, ARM32, x86):

1. Open your terminal in the `frontend` folder:
   ```bash
   cd "d:\AI Hackathon\NutriSense\frontend"
   ```

2. Clean and fetch packages:
   ```bash
   flutter clean
   flutter pub get
   ```

3. Run the build command:
   ```bash
   flutter build apk --release
   ```

4. Once the build finishes, your APK is generated at:
   ```text
   frontend/build/app/outputs/flutter-apk/app-release.apk
   ```

---

### Method B: Split-per-ABI APKs (Smaller File Size)
If you want smaller APK download sizes (e.g. ~20–30 MB instead of ~60 MB):

```bash
flutter build apk --split-per-abi --release
```
This generates 3 separate APKs in `build/app/outputs/flutter-apk/`:
* `app-arm64-v8a-release.apk` $\to$ **For almost all modern Android phones (Recommended)**.
* `app-armeabi-v7a-release.apk` $\to$ For older 32-bit Android phones.
* `app-x86_64-release.apk` $\to$ For PC Android emulators.

---

### Method C: Google Play Store App Bundle (`.aab`)
If you plan to publish to the Google Play Store:
```bash
flutter build appbundle --release
```
Outputs: `frontend/build/app/outputs/bundle/release/app-release.aab`.

---

## Part 4: Installing the APK on Devices

You can install `app-release.apk` on physical Android devices using any of these methods:

### Option 1: Direct USB Installation (Fastest for Devs)
1. Enable **USB Debugging** on your Android phone (Settings $\to$ Developer Options $\to$ USB Debugging).
2. Connect your phone via USB cable.
3. Run:
   ```bash
   flutter install
   ```
   *(or `adb install -r build/app/outputs/flutter-apk/app-release.apk`)*.

### Option 2: Share via Google Drive / WhatsApp
1. Locate `frontend/build/app/outputs/flutter-apk/app-release.apk`.
2. Rename it to `NutriSense-v1.0.apk` for easy sharing.
3. Upload it to Google Drive or send it via WhatsApp to your phone / judges / team members.
4. On the phone, tap the file $\to$ Click **Install**.
   *(If prompted: Allow "Install from unknown sources" in Android settings)*.

---

## Part 5: (Bonus) Deploying Flutter Web

If you also want judges to test the app in a web browser without installing an APK:

### 1. Build Flutter Web:
```bash
cd frontend
flutter build web --release
```
Outputs web build in `frontend/build/web/`.

### 2. Deploy to Vercel (Free & Instant):
1. Install Vercel CLI (or connect GitHub):
   ```bash
   npm i -g vercel
   ```
2. Navigate to web build folder and deploy:
   ```bash
   cd build/web
   vercel deploy --prod
   ```
3. You will get a live URL like: `https://nutrisense-app.vercel.app`.

---

## 🛠️ Troubleshooting & Pro Tips

### 1. "App Not Installed" on Android Phone
- **Cause**: An older debug build with a conflicting signature is already on the phone.
- **Fix**: Uninstall the existing NutriSense app from the phone first, then install the new `app-release.apk`.

### 2. Render Free Tier "Cold Start" Spin-down
- Render's free tier spins down the backend if inactive for 15 minutes. The first request after spin-down may take ~30–45 seconds to wake up.
- **Hackathon Demo Tip**: Open your Render URL (`https://your-api.onrender.com/docs`) in a browser tab 5 minutes before your demo presentation so the server is warm and responds instantly.

### 3. Testing Network Requests on Android
- If testing against a local backend (`http://10.0.2.2:8000` or local WiFi IP), Android blocks cleartext HTTP by default.
- Using the hosted HTTPS URL (e.g. `https://nutrisense-api.onrender.com`) avoids all cleartext security restrictions and works seamlessly on cellular data and WiFi.

---

*NutriSense is now production-ready for live evaluation, mobile installation, and hackathon presentation!*
