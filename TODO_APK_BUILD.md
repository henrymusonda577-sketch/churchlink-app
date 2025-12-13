# TODO: Build Release APK for Flutter App

## Completed Tasks
- [x] Updated pubspec.yaml with version 1.0.0+1
- [x] Updated AndroidManifest.xml with app name "My Flutter App"
- [x] Configured build.gradle.kts:
  - minSdk = 26 (Android 8.0)
  - targetSdk = 34
  - versionCode = 1
  - versionName = "1.0.0"
  - Added signingConfigs for release
  - Enabled minifyEnabled, shrinkResources for optimization
  - Added proguard-rules.pro
- [x] Created proguard-rules.pro with Flutter-specific rules

## Pending Tasks
- [x] Generate keystore for signing
- [ ] Set up Android SDK (ANDROID_HOME environment variable)
- [ ] Build release APK
- [ ] Verify APK output and compatibility

## Commands to Run
1. Navigate to the project directory:
   cd flutter_projects/my_flutter_app

2. Generate keystore (replace passwords with secure ones):
   keytool -genkey -v -keystore android/app/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key -storepass storepassword -keypass keypassword -dname "CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown"

3. Build the release APK:
   flutter build apk --release

4. The APK will be located at:
   build/app/outputs/flutter-apk/app-release.apk

## Notes
- Ensure Flutter SDK is installed and configured.
- Set ANDROID_HOME environment variable to your Android SDK path (e.g., C:\Users\%USERNAME%\AppData\Local\Android\Sdk on Windows).
- Test the APK on Android 8.0+ devices.
- For production, use a proper keystore and secure passwords.
- The APK is optimized for size and performance with ProGuard/R8 enabled.
