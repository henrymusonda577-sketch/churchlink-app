@echo off
echo Generating app icons...
flutter pub get
flutter pub run flutter_launcher_icons:main
echo App icons generated successfully!
pause