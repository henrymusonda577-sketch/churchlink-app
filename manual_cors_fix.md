# Manual CORS Fix for Firebase Storage

Since the automated script encountered an error, please manually set the CORS configuration in Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/project/allchurches-956e0/storage)
2. Select your project "allchurches-956e0"
3. Go to Storage > CORS configuration
4. Paste the following JSON:

```json
[
  {
    "origin": [
      "http://localhost:8080",
      "http://localhost:58832",
      "http://localhost:3000",
      "http://localhost:5000",
      "http://localhost:8081",
      "http://localhost:8082",
      "http://localhost:9099",
      "http://localhost:55316",
      "http://localhost:50461",
      "http://localhost:51146",
      "https://allchurches-956e0.web.app",
      "https://allchurches-956e0.firebaseapp.com",
      "http://127.0.0.1:8080",
      "http://127.0.0.1:3000",
      "http://127.0.0.1:5000",
      "http://127.0.0.1:55316",
      "http://127.0.0.1:50461",
      "http://127.0.0.1:51146"
    ],
    "method": ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"],
    "maxAgeSeconds": 3600,
    "responseHeader": [
      "Content-Type",
      "Authorization",
      "Content-Length",
      "Accept-Encoding",
      "X-CSRF-Token",
      "Firebase-Storage-Token",
      "Access-Control-Allow-Origin",
      "Access-Control-Allow-Methods",
      "Access-Control-Allow-Headers",
      "Access-Control-Max-Age"
    ]
  }
]
```

5. Click Save
6. Wait a few minutes for the configuration to take effect
7. Restart your Flutter app and test video upload again

This should resolve the CORS error for video uploads and downloads.
