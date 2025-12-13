# Supabase Email Setup Guide

## Step 1: Access Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Sign in to your account
3. Select your project: `dsdbbqdcreyevjwysvzq`

## Step 2: Configure Authentication Settings
1. In the left sidebar, click **Authentication**
2. Click **Settings** tab

### Enable Email Confirmations
1. Under **User Signups**, ensure **Enable email confirmations** is **ON**
2. This ensures users must verify their email before accessing the app

## Step 3: Configure Email Templates
1. In Authentication > Settings, scroll down to **Email Templates**
2. Click on **Email Templates** section

### Confirm Signup Template
1. Click on **Confirm signup**
2. Customize the email template:
   - **Subject**: `Confirm your Church-Link account`
   - **Message**: Use this template:

```
Hi {{ .Email }},

Welcome to Church-Link! Please click the link below to confirm your email address and complete your registration.

{{ .ConfirmationURL }}

If you didn't create an account, you can safely ignore this email.

Best regards,
Church-Link Team
```

3. Click **Save**

### Magic Link Template (Optional)
1. Click on **Magic link**
2. Customize if needed for password reset functionality

## Step 4: Configure SMTP Settings (Recommended for Production)
For production apps, you should configure custom SMTP settings:

1. In Authentication > Settings, scroll to **SMTP Settings**
2. Click **Enable custom SMTP**
3. Enter your SMTP provider details:
   - **Host**: Your SMTP server (e.g., smtp.gmail.com, smtp.sendgrid.com)
   - **Port**: Usually 587 (TLS) or 465 (SSL)
   - **User**: Your SMTP username/email
   - **Password**: Your SMTP password or API key
   - **Sender Address**: The email address that will appear as the sender

### Popular SMTP Providers:
- **SendGrid**: Free tier available, good for production
- **Mailgun**: Good alternative with free tier
- **Gmail**: For testing only (not recommended for production)
- **AWS SES**: Enterprise-grade solution

## Step 5: Test Email Configuration
1. Go back to your Flutter app
2. Try signing up with a real email address
3. Check your email inbox for the verification link
4. Click the link to verify the account

## Step 6: Verify Domain (Optional but Recommended)
If using custom SMTP:
1. In Authentication > Settings > Email Templates
2. Add your domain to the **Allowed Domains** list
3. This helps prevent email spoofing

## Troubleshooting

### Emails Not Being Sent
- Check if SMTP is configured correctly
- Verify SMTP credentials
- Check your SMTP provider's logs
- Ensure the email address is valid

### Emails Going to Spam
- Use a reputable SMTP provider
- Set up SPF, DKIM, and DMARC records for your domain
- Avoid spam trigger words in email content

### Verification Links Not Working
- Ensure the redirect URLs in Supabase Auth settings match your app's deep links
- Check that the email template includes `{{ .ConfirmationURL }}`

## Alternative: Use Supabase's Built-in Email (Development Only)
For development/testing, you can use Supabase's default email service, but it's limited and not suitable for production.

## Next Steps
After configuring email:
1. Test the signup flow
2. Verify users can receive and click verification emails
3. Test the complete user registration process

Let me know if you need help with any specific SMTP provider setup!
