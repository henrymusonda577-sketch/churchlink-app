@echo off
echo Building debug APK to check for errors...
flutter clean
flutter pub get
flutter build apk --debug
echo Debug APK built. Check for errors above.
pause