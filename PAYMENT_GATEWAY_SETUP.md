# Payment Gateway Setup Guide

Your Church-Link app now has real payment gateway integrations for:
- **Visa/Mastercard** (via Flutterwave)
- **Airtel Money** (Zambia)
- **MTN Mobile Money** (Zambia)

## 🚀 Quick Start

1. **Update credentials** in `lib/config/payment_config.dart`
2. **Test with small amounts** first
3. **Set `isTestMode = false`** for live payments

## 📋 Setup Instructions

### 1. Flutterwave (Visa/Mastercard)

**Steps:**
1. Go to [https://flutterwave.com/](https://flutterwave.com/)
2. Create business account
3. Complete KYC verification
4. Get API keys from Dashboard > Settings > API Keys

**Replace in `payment_config.dart`:**
```dart
static const String flutterwavePublicKey = "FLWPUBK-your-actual-key";
static const String flutterwaveSecretKey = "FLWSECK-your-actual-key";
```

**Cost:** 3.8% per transaction

### 2. Airtel Money (Zambia)

**Steps:**
1. Contact Airtel Money Business Team: +260-977-777-777
2. Apply for merchant account
3. Provide business documents
4. Get API credentials after approval

**Replace in `payment_config.dart`:**
```dart
static const String airtelClientId = "your-airtel-client-id";
static const String airtelClientSecret = "your-airtel-client-secret";
```

**Cost:** 1-3% per transaction

### 3. MTN Mobile Money (Zambia)

**Steps:**
1. Contact MTN MoMo Business Team: +260-966-000-100
2. Apply for merchant account
3. Get API access and subscription key
4. Complete integration testing

**Replace in `payment_config.dart`:**
```dart
static const String mtnApiKey = "your-mtn-api-key";
static const String mtnApiSecret = "your-mtn-api-secret";
static const String mtnSubscriptionKey = "your-subscription-key";
```

**Cost:** 1-2% per transaction

## 🔧 Configuration

### Current Settings
- **Company Airtel Number:** 0973644384
- **Company MTN Number:** 0964536477
- **Test Mode:** Enabled (change to false for live)

### Update Company Numbers
Change these in `payment_config.dart` to your actual business numbers:
```dart
static const String airtelCompanyNumber = "097XXXXXXX";
static const String mtnCompanyNumber = "096XXXXXXX";
```

## 🧪 Testing

1. **Keep `isTestMode = true`** during testing
2. **Use test amounts** (ZMW 1-10)
3. **Test all payment methods**
4. **Verify transactions** in respective dashboards

## 🚀 Go Live

1. **Complete all verifications**
2. **Set `isTestMode = false`**
3. **Update to live URLs** (MTN)
4. **Test with real small amounts**
5. **Monitor transactions**

## 📱 User Experience

**Visa/Mastercard:**
- Opens Flutterwave payment page
- User enters card details
- Redirects back to app

**Airtel Money:**
- User enters PIN in app
- Push notification sent to phone
- User approves on phone

**MTN Mobile Money:**
- User enters PIN in app
- USSD prompt sent to phone
- User approves transaction

## 🔒 Security Notes

- **Never commit real credentials** to version control
- **Use environment variables** in production
- **Implement transaction logging**
- **Add fraud detection**
- **Regular security audits**

## 📊 Transaction Flow

1. User selects payment method
2. App validates amount and details
3. Payment gateway processes request
4. Transaction logged in Firestore
5. User receives confirmation
6. Church receives funds

## 🆘 Support Contacts

**Flutterwave:** support@flutterwave.com
**Airtel Money:** +260-977-777-777
**MTN MoMo:** +260-966-000-100

## 💰 Expected Costs

**Monthly Volume: ZMW 10,000**
- Flutterwave: ~ZMW 380 (3.8%)
- Airtel Money: ~ZMW 200 (2%)
- MTN MoMo: ~ZMW 150 (1.5%)

**Setup Fees:**
- Flutterwave: Free
- Airtel Money: ~ZMW 500
- MTN MoMo: ~ZMW 300

---

**Status:** ✅ Integration Complete - Ready for Credential Setup
**Next Step:** Contact payment providers to get live credentials