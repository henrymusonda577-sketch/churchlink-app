# TODO: Build APK for Flutter App

## Information Gathered
- The project is a Flutter app with Android configuration in the `android/` directory.
- Batch files exist for building APK: `build_apk.bat` (universal and split APKs), `rebuild_apk.bat` (simple rebuild), `debug_apk.bat` (debug build).
- `build_apk.bat` performs cleaning, dependency fetching, Flutter clean, and builds release APK with universal architecture support for Tecno Pop 10 compatibility.
- Gradle files are configured: `android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle.properties`.
- `pubspec.yaml` has version 1.0.0+1, dependencies include Supabase, Firebase, etc.
- `flutter doctor` shows Android toolchain is available (SDK version 36.1.0-rc1), but some issues with Visual Studio and Android Studio Java version.
- The build script is currently running via `.\build_apk.bat`.

## Plan
- Execute the APK build using the existing `build_apk.bat` script, which handles cleaning, dependencies, and building universal and split APKs.
- Monitor the build process for any errors.
- If build succeeds, verify the output APKs in `build/app/outputs/flutter-apk/`.
- If errors occur, troubleshoot based on TODO files (e.g., set ANDROID_HOME, check SDK).

## Dependent Files
- No file edits needed; this is a build execution task.
- Relies on: `build_apk.bat`, Flutter SDK, Android SDK.

## Followup Steps
- After build completes, check for APK files.
- Test APK on device if possible.
- If issues, refer to TODO_APK_BUILD_FIX.md for SDK setup.
