# Android SDK Installation and Configuration for Flutter APK Build on Windows

## Step 1: Download Android Command Line Tools
- Visit: https://developer.android.com/studio#command-tools
- Download the **Command line tools only** for Windows.

## Step 2: Extract Command Line Tools
- Extract the downloaded zip file to a directory, for example:
  ```
  C:\Android\cmdline-tools
  ```

## Step 3: Set Environment Variables
- Open **System Properties** > **Environment Variables**.
- Add a new system variable:
  - Variable name: `ANDROID_HOME`
  - Variable value: `C:\Android`
- Edit the `Path` system variable and add:
  ```
  %ANDROID_HOME%\cmdline-tools\bin
  %ANDROID_HOME%\platform-tools
  ```

## Step 4: Install SDK Packages
- Open a new Command Prompt window.
- Run the following commands to install necessary SDK components:
  ```
  sdkmanager --install "platform-tools" "platforms;android-33" "build-tools;33.0.2"
  ```
- Accept all licenses:
  ```
  sdkmanager --licenses
  ```

## Step 5: Verify Installation
- Run:
  ```
  flutter doctor
  ```
- Ensure Android SDK is detected and no errors are shown.

## Step 6: Build APK
- Run:
  ```
  flutter build apk --release
  ```
- The APK should be generated in the `build/app/outputs/flutter-apk` directory.

---

Follow these steps carefully to fix the Android SDK missing issue and successfully build your Flutter APK.
