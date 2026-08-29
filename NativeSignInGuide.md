# Native Google Sign-In Setup Guide

This guide walks you through the step-by-step setup required to enable native Google Sign-In on mobile devices for the **NutriSense** application. Using native Google Sign-In bypasses the external web browser redirects and prevents showing the `*.supabase.co` URL on Google's consent screen.

---

## Step 1: Configure Credentials in Google Cloud Console

1. Open the [Google Cloud Console Credentials Page](https://console.cloud.google.com/apis/credentials).
2. Select your active Firebase/Google Cloud project.
3. **Create OAuth 2.0 Web Client ID (Mandatory):**
   - Click **Create Credentials** -> **OAuth client ID**.
   - Select **Web application** as the Application type.
   - Set Name to `NutriSense Web Client (Supabase)`.
   - Leave Authorized redirect URIs empty for native authentication.
   - Click **Create** and copy the **Client ID** (this will be your `serverClientId`).
4. **Create OAuth 2.0 Android Client ID:**
   - Click **Create Credentials** -> **OAuth client ID**.
   - Select **Android** as the Application type.
   - Set Name to `NutriSense Android Client`.
   - Provide the Package name: `com.example.frontend` (from `frontend/android/app/build.gradle.kts`).
   - Provide the **SHA-1 certificate fingerprint**:
     - **Debug SHA-1**: `A4:38:21:7C:C9:9D:70:D1:FF:20:4D:97:C2:B1:72:39:1A:C1:C0:E5`
     - **Debug SHA-256**: `A9:D8:EE:33:71:84:FE:76:12:C3:8D:35:83:94:85:13:98:A1:CC:CC:9C:FB:D4:B5:CF:BB:B4:B2:6F:C8:5E:E6`
     - *(Optional)* To regenerate the fingerprint yourself:
       ```powershell
       & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
       ```
   - Click **Create**.
5. **Create OAuth 2.0 iOS Client ID (Optional):**
   - Click **Create Credentials** -> **OAuth client ID**.
   - Select **iOS** as the Application type.
   - Set Name to `NutriSense iOS Client`.
   - Provide your iOS Bundle ID.
   - Click **Create**.

---

## Step 2: Configure Supabase Authentication

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard).
2. Navigate to **Authentication** -> **Providers** -> **Google**.
3. Toggle **Skip nonce check** to **ON** (this is required for native OAuth ID token flow).
4. Under **Authorized Client IDs**, add the Client IDs you created in Step 1:
   - Paste the **Web Client ID**.
   - Paste the **Android Client ID**.
   - Paste the **iOS Client ID** (if applicable).
5. Click **Save**.

---

## Step 3: Populate Local Configuration (`frontend/.env`)

Add the following environment variables to your `frontend/.env` file:
```env
GOOGLE_WEB_CLIENT_ID=your-web-client-id-from-step-1.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=your-ios-client-id-from-step-1.apps.googleusercontent.com
```

---

## Step 4: Verification

Once the configuration is complete, run the application locally on your device or emulator:
```bash
.\run_frontend.bat
```
Tapping the "Sign In with Google" button will now trigger a native Android or iOS system account selection sheet directly inside the application, removing any browser warning screens.
