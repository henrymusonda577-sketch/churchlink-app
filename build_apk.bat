@echo off
echo Building Church-Link APK for Tecno Pop 10 compatibility...

REM Clean previous builds
echo Cleaning previous builds...
if exist build rmdir /s /q build
if exist .dart_tool rmdir /s /q .dart_tool

REM Get dependencies
echo Getting dependencies...
flutter pub get

REM Clean Flutter
echo Cleaning Flutter cache...
flutter clean

REM Build APK with universal architecture support
echo Building universal APK...
flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --split-per-abi=false --obfuscate --split-debug-info=debug-info

REM Also build split APKs as backup
echo Building split APKs...
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=debug-info

echo.
echo Build complete!
echo Universal APK: build\app\outputs\flutter-apk\app-release.apk
echo Split APKs: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo            build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
echo            build\app\outputs\flutter-apk\app-x86_64-release.apk

pause