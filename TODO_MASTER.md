# Master TODO - Complete All 5 Areas

## 1. Donation Integration (TODO_DONATION_INTEGRATION.md)
- [ ] Install Flutter packages (flutter pub get)
- [ ] Deploy Firebase Functions (firebase deploy --only functions)
- [ ] Test payment flow on device/emulator
- [ ] Test webhook handling
- [ ] Update CORS if needed for webhooks

## 2. Donate Church Selection (TODO_DONATE_CHURCH_SELECTION.md)
- [x] Verify ChurchService import in donate_screen.dart
- [x] Verify church state variables are implemented
- [x] Verify church loading methods are implemented
- [x] Verify church selection UI is working
- [ ] Test church selection functionality

## 3. Donation Fix (TODO_DONATION_FIX.md)
- [x] Implement _processAirtelPayment method in donation_service.dart
- [x] Implement _processMtnPayment method in donation_service.dart
- [x] Update initiatePayment to route to appropriate payment processor
- [x] Add comprehensive error handling
- [ ] Test Airtel Money payment flow
- [ ] Test MTN Mobile Money payment flow
- [ ] Test Visa/Mastercard payment flow

## 4. Video Post Feed (TODO_VIDEO_POST_FEED.md)
- [ ] Assess current video functionality
- [ ] Implement video post feed UI
- [ ] Add video upload capability
- [ ] Add video playback in feed
- [ ] Test video functionality

## 5. Church Chat Voice Notes (TODO_CHURCH_CHAT_VOICE_NOTES.md)
- [ ] Verify voice message UI implementation
- [ ] Verify image message display
- [ ] Verify video message display
- [ ] Test voice message recording and playback
- [ ] Test image/video message sending and display

## Testing & Deployment
- [ ] Critical-path testing for all features
- [ ] Deploy Firebase functions
- [ ] Test payment integrations
- [ ] Verify all TODO items are completed
