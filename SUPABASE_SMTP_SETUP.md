# Supabase SMTP Setup Guide

## Step 1: Set Up Mailgun Account
1. Go to [Mailgun's website](https://signup.mailgun.com/new/signup) and create a free account
2. Verify your account with a credit card (required for sandbox testing)
3. Complete the setup process

## Step 2: Get SMTP Credentials
1. In Mailgun dashboard, go to Sending > Domains
2. Click on your sandbox domain (or custom domain if you've added one)
3. Click on "SMTP" section to view your credentials
4. Note down:
   - SMTP Hostname
   - Port number
   - Username (usually "postmaster@your-domain")
   - Password (your SMTP password)

## Step 3: Add and Verify Your Domain (Optional for Production)
1. In Mailgun dashboard, go to Sending > Domains
2. Click "Add New Domain"
3. Follow the DNS setup instructions
4. Wait for domain verification (usually takes 24-48 hours)
5. For testing, you can use the sandbox domain

## Step 4: Configure Supabase SMTP
1. Go to your Supabase project dashboard
2. Navigate to Authentication > Email Templates
3. Click on "SMTP Settings"
4. Enter the following details:
   ```
   Host: smtp.mailgun.org
   Port: 587
   User: [Your Mailgun SMTP Username]
   Password: [Your Mailgun SMTP Password]
   Sender Name: [Your Church Name]
   Sender Email: [Your Mailgun sandbox/domain email]
   ```
5. Click "Save Changes"

## Step 5: Test Email Configuration
1. In your Supabase dashboard, go to Authentication > Users
2. Click "New User"
3. Enter test email and password
4. Check if verification email is received
5. Check Authentication > Logs for delivery status

## Step 6: Update Email Templates
1. In Supabase dashboard, go to Authentication > Email Templates
2. Customize the "Confirm Signup" template
3. Add your church branding and logo
4. Include clear instructions about the 6-digit code
5. Save and test the template

## Troubleshooting
If emails are not being received:
1. Check Supabase Auth logs for delivery attempts
2. Verify SendGrid's Email Activity page for delivery status
3. Ensure domain verification is complete
4. Check spam folders
5. Verify SMTP credentials are correct
6. Ensure sender email matches verified domain

## Support Links
- [SendGrid Documentation](https://docs.sendgrid.com/)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Email Troubleshooting Guide](https://supabase.com/docs/guides/auth/auth-smtp-issues)