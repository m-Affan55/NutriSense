# Deployment Plan: Flutter Web Frontend on Vercel

This plan details the steps required to deploy the NutriSense Flutter Web frontend application to Vercel, connecting it with your already deployed live Render backend.

---

## 🏗️ Deployment Strategy

Even though you are developing on a **Windows PC**, Vercel's remote build servers run on **Linux**. Therefore, we will use a **custom shell script** (`vercel-build.sh`) that Vercel's Linux servers will execute during git deployment to fetch Flutter, configure your gitignored environment variables, and compile the release build.

> [!IMPORTANT]
> **Windows line-endings warning**: Since you are on Windows, ensure that your text editor (VS Code, Notepad++, etc.) saves the `vercel-build.sh` file with **LF (Linux)** line endings instead of **CRLF (Windows)**. CRLF line endings will cause the script to fail to run on Vercel's Linux servers.

---

## 🛠️ Step-by-Step Instructions

### Step 1: Create Build Script `vercel-build.sh`
Create a file named `vercel-build.sh` inside your `frontend/` directory (I can write this file directly into your local workspace with LF endings for you once you approve):

```bash
#!/bin/bash

# 1. Create the .env file from Vercel Environment Variables
echo "SUPABASE_URL=$SUPABASE_URL" > .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
echo ".env file generated successfully."

# 2. Clone Flutter SDK (Stable Channel)
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Build Flutter Web Release
flutter doctor
flutter build web --release
```

---

### Step 2: Configure Vercel Project Settings
When importing your repository on the Vercel Dashboard, set these parameters:

1. **Framework Preset**: Choose **"Other"**.
2. **Root Directory**: Set to **`frontend`**.
3. **Build & Development Settings**:
   * **Build Command**: `bash vercel-build.sh`
   * **Output Directory**: `build/web` (this matches your `vercel.json` config).
4. **Environment Variables**:
   Add the following variables to connect your app to Supabase (matching your local `.env` keys):
   * `SUPABASE_URL` = *[Your production Supabase project URL]*
   * `SUPABASE_ANON_KEY` = *[Your production Supabase anon key]*

---

### Step 3: Trigger Build
* Click **Deploy**. Vercel will install the Flutter SDK, build the release, and host it.
* Future pushes to your repository will automatically trigger rebuilds.
