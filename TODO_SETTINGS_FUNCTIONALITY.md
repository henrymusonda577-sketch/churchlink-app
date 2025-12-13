# TODO: Implement Settings Functionality

## Overview
Make all settings options functional, starting with dark mode as example.

## Tasks
- [ ] Create ThemeProvider for managing app theme (light/dark)
- [ ] Update main.dart to use ThemeProvider and support theme switching
- [ ] Update settings_screen.dart to use ThemeProvider for dark mode toggle
- [ ] Test dark mode functionality
- [ ] Implement language selection (basic, without full localization)
- [ ] Implement notification settings integration with NotificationService
- [ ] Implement privacy settings (frontend logic, backend may need updates)
- [ ] Implement security settings (2FA placeholder)

## Files to Edit
- lib/services/theme_provider.dart (new)
- lib/main.dart
- lib/settings_screen.dart
- lib/services/notification_service.dart (if needed)

## Notes
- Dark mode: Use ThemeMode and separate light/dark themes
- Language: Save selection, but no full i18n for now
- Notifications: Integrate with existing NotificationService
- Privacy/Security: Frontend saves, backend logic needed later
