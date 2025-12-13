# Camera and Microphone Permissions Setup

This document provides guidance for setting up and troubleshooting camera and microphone permissions in your Flutter app.

## Android Permissions

### 1. AndroidManifest.xml Configuration

Ensure your `android/app/src/main/AndroidManifest.xml` includes the required permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Camera permission -->
    <uses-permission android:name="android.permission.CAMERA" />

    <!-- Microphone permission -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />

    <!-- Optional: For better camera access -->
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />

    <application>
        <!-- ... other configurations ... -->
    </application>
</manifest>
```

### 2. Runtime Permission Requests

Your app should request permissions at runtime. The WebRTCCallService should handle permission requests before calling `getUserMedia()`.

## iOS Permissions

### 1. Info.plist Configuration

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls and photo uploads</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice calls and audio recording</string>
```

### 2. App Capabilities

In Xcode, ensure your app has the required capabilities:
- Camera
- Microphone

## Flutter Permission Handling

### 1. Add Permission Handler Package

Add to your `pubspec.yaml`:

```yaml
dependencies:
  permission_handler: ^11.0.1
```

### 2. Request Permissions in WebRTCCallService

Update your WebRTCCallService to request permissions before accessing media:

```dart
import 'package:permission_handler/permission_handler.dart';

class WebRTCCallService {
  // ... existing code ...

  Future<void> initLocalStream({bool audio = true, bool video = true}) async {
    try {
      // Request permissions first
      await _requestPermissions(audio: audio, video: video);

      _localStream = await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': audio,
        'video': video ? {'facingMode': 'user'} : false,
      });
    } catch (e) {
      print('Error initializing local stream: $e');
      rethrow;
    }
  }

  Future<void> _requestPermissions({bool audio = true, bool video = true}) async {
    List<Permission> permissions = [];

    if (video) {
      permissions.add(Permission.camera);
    }

    if (audio) {
      permissions.add(Permission.microphone);
    }

    // Request permissions
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // Check if all permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      // Handle denied permissions
      for (var entry in statuses.entries) {
        if (!entry.value.isGranted) {
          print('Permission ${entry.key} denied: ${entry.value}');
        }
      }
      throw Exception('Required permissions not granted');
    }
  }
}
```

## Troubleshooting Permission Issues

### 1. Check Device Settings

- **Android**: Settings → Apps → [Your App] → Permissions
- **iOS**: Settings → [Your App] → Camera/Microphone toggles

### 2. Permission Denied Scenarios

- **First time**: App should request permission
- **Previously denied**: App needs to show explanation and guide user to settings
- **Permanently denied**: User must manually enable in device settings

### 3. Enhanced Permission Request

```dart
Future<void> _requestPermissionsWithGuidance({bool audio = true, bool video = true}) async {
  List<Permission> permissions = [];

  if (video) permissions.add(Permission.camera);
  if (audio) permissions.add(Permission.microphone);

  Map<Permission, PermissionStatus> statuses = await permissions.request();

  for (var entry in statuses.entries) {
    if (entry.value.isPermanentlyDenied) {
      // Show dialog guiding user to settings
      await _showPermissionSettingsDialog(entry.key);
    } else if (!entry.value.isGranted) {
      // Permission denied but not permanently
      print('Permission ${entry.key} denied');
    }
  }
}

Future<void> _showPermissionSettingsDialog(Permission permission) async {
  // Show dialog explaining why permission is needed and how to enable it
  // Then open app settings
  await openAppSettings();
}
```

### 4. Testing Permissions

#### Android Testing
```bash
# Grant permissions via ADB (for testing)
adb shell pm grant com.your.package.name android.permission.CAMERA
adb shell pm grant com.your.package.name android.permission.RECORD_AUDIO
```

#### iOS Testing
- Test on physical device (simulator doesn't have camera/microphone)
- Check console logs for permission-related messages

### 5. Common Issues

1. **Permission not requested**: Ensure `request()` is called before `getUserMedia()`
2. **iOS permission dialog not showing**: Check Info.plist entries
3. **Android permission denied**: Check AndroidManifest.xml and target SDK
4. **WebRTC failures**: Ensure permissions are granted before WebRTC initialization

### 6. Fallback Handling

```dart
Future<void> initLocalStream({bool audio = true, bool video = true}) async {
  try {
    await _requestPermissions(audio: audio, video: video);

    _localStream = await webrtc.navigator.mediaDevices.getUserMedia({
      'audio': audio,
      'video': video ? {'facingMode': 'user'} : false,
    });
  } on Exception catch (e) {
    if (e.toString().contains('Permission denied')) {
      // Handle permission denied - show user-friendly message
      throw Exception('Camera/microphone access denied. Please enable permissions in settings.');
    } else {
      // Handle other WebRTC errors
      throw Exception('Failed to access camera/microphone: $e');
    }
  }
}
```

## Additional Considerations

- **Privacy**: Clearly explain why permissions are needed
- **Graceful degradation**: Allow app to work with limited permissions (e.g., audio-only calls)
- **User education**: Guide users on how to enable permissions
- **Testing**: Test on various devices and OS versions
