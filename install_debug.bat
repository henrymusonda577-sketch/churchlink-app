@echo off
echo Installing Church-Link Debug APK...
adb install -r build\app\outputs\flutter-apk\app-debug.apk
echo.
echo Installation complete! 
echo Now open the app on your phone and check for any error messages.
echo.
echo To see live logs while testing:
echo adb logcat -s flutter
pause