@echo off
echo Rebuilding Church-Link APK with fixes...
flutter clean
flutter pub get
flutter build apk --release
echo APK rebuilt successfully!
pause