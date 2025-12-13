# Donation Integration with Flutterwave - TODO

## Completed Tasks
- [x] Analyze existing code and plan integration
- [x] Create TODO file
- [x] Add flutterwave_standard and http packages to pubspec.yaml
- [x] Create donation_service.dart in lib/services/
- [x] Update donate_screen.dart:
  - Add purpose selector (church vs app support)
  - Update payment methods to Airtel Money, MTN Mobile Money, Visa/Mastercard
  - Add optional message field
  - Integrate Flutterwave SDK for payment processing
  - Implement error handling and success feedback
- [x] Create functions/ directory
- [x] Create functions/package.json with dependencies
- [x] Create functions/index.js for Firebase Functions:
  - Payment webhook handler
  - Donation logging to Firestore
  - Confirmation message sending
- [x] Update firestore.rules for donations collection

## Testing & Deployment
- [ ] Install Flutter packages (flutter pub get)
- [ ] Deploy Firebase Functions (firebase deploy --only functions)
- [ ] Test payment flow on device/emulator
- [ ] Test webhook handling
- [ ] Update CORS if needed for webhooks

## Future Enhancements
- [ ] Recurring donations
- [ ] Donation history view
- [ ] Admin dashboard for donations
