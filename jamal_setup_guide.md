# Local Setup Guide & Version Clashes

Hi Jamal, as you are running on an older version of Android, you might run into a few version clashes and issues when pulling the `feature_enhancements` branch to replace your `features` branch. 

Here is a breakdown of what has changed, why it might clash with your older device, and how you can successfully run the project!

## 📦 What Changed in `pubspec.yaml` and `pubspec.lock`
We have added several new dependencies and updated existing ones since your `features` branch to support the new Voice Assistant and PDF Exports:
- Added `speech_to_text: ^7.4.0`
- Added `flutter_tts: ^4.2.5`
- Added `permission_handler: ^13.0.1`
- Added `path_provider: ^2.1.2`
- Added `open_file: ^3.3.2`
- Updated `health` from `^12.0.0` to `^13.3.2`

**The Clash:** 
Because you are running an older Android device, these newer packages (especially `speech_to_text`, `health 13.3.2`, and `permission_handler`) typically require a higher `minSdkVersion` in Android than older packages did. If your Android API level is too low (e.g., API 21), these packages will throw a build error or fail to run when you try to execute `run_frontend.bat`.

## 🚀 How to Successfully Run the Project

1. **Fix the `minSdkVersion` (If needed):**
   If you get an error during `flutter run` about the SDK version, open `frontend/android/app/build.gradle` and change the `minSdkVersion`. You might need to update it to `23` or `24` depending on the exact error the `health` or `speech_to_text` packages give you.
   
2. **Clean and Rebuild:**
   Because there are heavy additions in `pubspec.lock` (updating `health` and adding 5 new libraries), you will definitely have a version clash if you don't clean your project first. Open your terminal in the `frontend` folder and run:
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Check ADB Reverse Setup:**
   You already had this in the `features` branch, but as a reminder, `run_frontend.bat` uses `adb reverse tcp:8000 tcp:8000`. If you see a warning about ADB failing, just remember that you need to have **USB Debugging** enabled on your phone and plugged into your computer for your physical phone to talk to the local backend smoothly!

4. **Launch the App:**
   Once `flutter clean` is done and your phone is plugged in, use `./run_frontend.bat` to launch the app!
