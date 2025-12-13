# Instructions to Deploy CORS Configuration to Firebase Storage

The CORS configuration file `cors.json` is present and correctly configured for your Firebase Storage bucket. To resolve the CORS errors you are encountering, you need to deploy this configuration to your Firebase Storage bucket.

## Using Firebase CLI

1. Install Firebase CLI if not already installed:
   ```
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```
   firebase login
   ```

3. Set your project (replace `your-project-id` with your Firebase project ID):
   ```
   firebase use your-project-id
   ```

4. Deploy the CORS configuration:
   ```
   gsutil cors set cors.json gs://your-project-id.appspot.com
   ```

   Note: `gsutil` is part of the Google Cloud SDK. If you don't have it installed, follow instructions here: https://cloud.google.com/sdk/docs/install

## Using gsutil directly

1. Install Google Cloud SDK and initialize it:
   ```
   gcloud init
   ```

2. Deploy the CORS config:
   ```
   gsutil cors set cors.json gs://your-project-id.appspot.com
   ```

## Verify

After deployment, clear your browser cache and retry the upload or video access. The CORS errors should be resolved.

---

If you want, I can help you create a PowerShell script to automate this deployment.

---

## Testing Preferences

Please confirm if you want me to proceed with:

- Critical-path testing (key elements only) for emoji and video fixes
- Thorough testing (complete coverage) for all related features
