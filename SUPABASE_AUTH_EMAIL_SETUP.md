# Supabase Auth Email Confirmation Setup

Since we've switched to using Supabase's built-in email confirmation instead of custom verification codes, you need to configure the email templates in your Supabase dashboard.

## Step 1: Access Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Sign in to your account
3. Select your project: `dsdbbqdcreyevjwysvzq`

## Step 2: Enable Email Confirmations
1. In the left sidebar, click **Authentication**
2. Click **Settings** tab
3. Under **User Signups**, ensure **Enable email confirmations** is **ON**

## Step 3: Configure Email Templates
1. In Authentication > Settings, scroll down to **Email Templates**
2. Click on **Email Templates** section

### Confirm Signup Template
1. Click on **Confirm signup**
2. Customize the email template:
   - **Subject**: `Confirm your Church-Link account`
   - **Message**: Use this template:

```
Hi there,

Welcome to Church-Link! Please click the link below to confirm your email address and complete your registration.

{{ .ConfirmationURL }}

If you didn't create an account, you can safely ignore this email.

Best regards,
Church-Link Team
```

3. Click **Save**

## Step 4: Configure Redirect URLs (Important for Mobile Apps)
1. In Authentication > Settings, scroll to **Redirect URLs**
2. Add your app's deep link URLs:
   - For web: `http://localhost:3000` (for development)
   - For mobile: Add your app's deep link schemes
     - `churchlink://verified`
     - Your Supabase project URL for auth redirects

## Step 5: Test the Configuration
1. Try signing up with a real email address in your app
2. Check your email inbox for the confirmation link
3. Click the link to verify the account
4. The app should automatically handle the confirmation and complete the signup process

## Troubleshooting

### Emails Not Being Sent
- Check Supabase Auth logs in the dashboard
- Ensure email confirmations are enabled
- Verify the email template is saved

### Confirmation Links Not Working
- Ensure the redirect URLs in Supabase match your app's deep links
- Check that the email template includes `{{ .ConfirmationURL }}`
- For mobile apps, ensure deep links are properly configured in AndroidManifest.xml and iOS

### Users Not Getting Signed In After Confirmation
- The Supabase Flutter SDK should automatically handle the auth state change
- Check that your app is listening to `onAuthStateChange` events
- Ensure the `EmailConfirmationPendingScreen` is properly handling the sign-in event

## Next Steps
After configuring email templates:
1. Test the complete signup flow
2. Verify users can receive and click confirmation emails
3. Test on both web and mobile platforms
4. Monitor Supabase Auth logs for any issues