# Fixing 'sdkmanager' Not Recognized Error on Windows

## Step 1: Download Android Command Line Tools
- Go to https://developer.android.com/studio#command-tools
- Download the **Command line tools only** for Windows.

## Step 2: Extract Command Line Tools
- Extract the zip file to a directory, for example:
  ```
  C:\Android\cmdline-tools\latest
  ```
- The folder structure should look like:
  ```
  C:\Android\cmdline-tools\latest\bin\sdkmanager.bat
  ```

## Step 3: Set Environment Variables
- Open **System Properties** > **Environment Variables**.
- Add or update the system variable:
  - `ANDROID_HOME` = `C:\Android`
- Edit the `Path` system variable and add:
  ```
  %ANDROID_HOME%\cmdline-tools\latest\bin
  %ANDROID_HOME%\platform-tools
  ```

## Step 4: Verify sdkmanager Access
- Open a new Command Prompt.
- Run:
  ```
  sdkmanager --list
  ```
- If the command runs and lists SDK packages, sdkmanager is correctly set up.

## Step 5: Install SDK Packages
- Run:
  ```
  sdkmanager --install "platform-tools" "platforms;android-33" "build-tools;33.0.2"
  ```
- Accept licenses:
  ```
  sdkmanager --licenses
  ```

## Step 6: Verify with Flutter
- Run:
  ```
  flutter doctor
  ```
- Confirm Android SDK is detected and no errors.

## Step 7: Build APK
- Run:
  ```
  flutter build apk --release
  ```
- APK will be generated in `build/app/outputs/flutter-apk`.

---

Follow these steps carefully to fix the sdkmanager command not found error and complete your Flutter APK build.
