import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey:
        'AIzaSyBXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', // Replace with your web API key
    appId:
        '1:XXXXXXXXXXXX:web:XXXXXXXXXXXXXXXXXXXXXX', // Replace with your web app ID
    messagingSenderId: 'XXXXXXXXXXXX', // Replace with your messaging sender ID
    projectId: 'your-project-id', // Replace with your project ID
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.appspot.com',
    measurementId: 'G-XXXXXXXXXX', // Optional
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        'AIzaSyBXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', // Replace with your Android API key
    appId:
        '1:XXXXXXXXXXXX:android:XXXXXXXXXXXXXXXXXXXXXX', // Replace with your Android app ID
    messagingSenderId: 'XXXXXXXXXXXX', // Replace with your messaging sender ID
    projectId: 'your-project-id', // Replace with your project ID
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:
        'AIzaSyBXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', // Replace with your iOS API key
    appId:
        '1:XXXXXXXXXXXX:ios:XXXXXXXXXXXXXXXXXXXXXX', // Replace with your iOS app ID
    messagingSenderId: 'XXXXXXXXXXXX', // Replace with your messaging sender ID
    projectId: 'your-project-id', // Replace with your project ID
    storageBucket: 'your-project-id.appspot.com',
  );
}
