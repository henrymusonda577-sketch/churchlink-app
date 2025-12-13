# TODO: Switch to Supabase Built-in Email Confirmation

## Steps to Complete:
- [x] Update lib/signup_screen.dart to use Supabase's signUp method with email confirmation enabled
- [x] Modify lib/email_confirmation_pending_screen.dart to handle Supabase's email confirmation flow
- [x] Remove or update lib/services/verification_service.ts (remove custom verification logic)
- [x] Update lib/main.dart to properly handle email confirmation states in auth flow
- [x] Remove supabase/functions/send-code/index.ts (no longer needed)
- [x] Remove supabase/functions/verify-code/index.ts (no longer needed)
- [x] Remove supabase/functions/cleanup-expired-codes/index.ts (no longer needed)
- [x] Update config files (supabase/functions/send-code/config.toml, supabase/functions/verify-code/config.toml) - remove if not needed
- [ ] Manually configure Supabase dashboard for email confirmations (follow SUPABASE_AUTH_EMAIL_SETUP.md)
  - Enable email confirmations in Authentication > Settings
  - Customize email templates (Confirm signup template)
  - Configure redirect URLs for mobile app deep links
- [ ] Test the updated signup flow
- [ ] Remove unused custom verification code tables/migrations if applicable
