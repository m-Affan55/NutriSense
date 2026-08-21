# Windows Platform Desktop Crash Fixes Walkthrough

We have successfully resolved the native desktop-specific runtime crashes occurring when running the app on Windows, as well as the compiler/analysis warnings related to path spacing:

## What Was Resolved

### 1. SQLite FFI initialization Error (Windows Desktop)
- **Problem**: When attempting offline caching on Windows, `sqflite` crashed with `databaseFactory not initialized`. This is because standard SQLite databases on desktop operating systems require FFI binding initializations.
- **Solution**:
  - Added `sqflite_common_ffi: ^2.4.2+1` to the frontend package dependencies.
  - Updated [main.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/main.dart) to import `package:sqflite_common_ffi/sqflite_common_ffi.dart` and `package:sqflite/sqflite.dart`.
  - Added initialization block at the very start of the `main()` method:
    ```dart
    if (!kIsWeb && Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    ```
  - This initializes the sqlite3 library binding for Windows desktop correctly.

### 2. Health Connect Permission crash (Windows Desktop)
- **Problem**: Health Connect permissions setup failed with `type 'Null' is not a subtype of type 'String'` because the `health` plugin was attempting to configure platform channel listeners on an unsupported platform (Windows).
- **Solution**:
  - Updated [health_service.dart](file:///d:/AI%20Hackathon/NutriSense/frontend/lib/core/health_service.dart) to import `dart:io`.
  - Guarded all permissions and fetch methods with platform capability checks:
    ```dart
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return ...
    ```
  - If executed on Windows, the service immediately returns clean defaults (`false` for availability, `ActivityData.empty` for data fetches) without ever invoking the native `health` package configuration.

### 3. Windows Path Encoding Spacing Workaround (`%20` bug)
- **Problem**: On Windows, if the local user profile name contains spaces (e.g. `Jamal Matloob`), the Dart compiler occasionally fails to decode URL-encoded paths (e.g., `/C:/Users/Jamal%20Matloob/AppData/Local/Pub/Cache/hosted/...`), throwing a file-not-found compilation error.
- **Solution**:
  - Setting the `PUB_CACHE` environment variable to a space-free path (e.g. `d:\.pub_cache` or `C:\.pub_cache`) bypasses this issue entirely since the package URI references contain no spaces.
  - When running commands manually in PowerShell or CMD, prepend:
    ```powershell
    $env:PUB_CACHE="d:\.pub_cache"
    ```
  - To set this permanently on your system, go to Windows **System Properties -> Environment Variables -> User Variables**, and add:
    * **Variable**: `PUB_CACHE`
    * **Value**: `d:\.pub_cache` (or any custom folder path that does not contain spaces).

---

## Verification Results

### Automated Verification
- Configured a local `.pub_cache` folder at `d:\.pub_cache` and ran compilation tests:
  ```bash
  E:\Flutter\flutter\bin\flutter.bat test
  ```
  **Result**: `All tests passed!` (Clean compile and execution).
