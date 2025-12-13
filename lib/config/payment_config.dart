class PaymentConfig {
  // IMPORTANT: Replace these with your actual live credentials
  
  // Flutterwave Live Credentials
  static const String flutterwavePublicKey = "FLWPUBK-your-live-public-key-here";
  static const String flutterwaveSecretKey = "FLWSECK-your-live-secret-key-here";
  static const String flutterwaveEncryptionKey = "your-live-encryption-key-here";
  
  // Airtel Money Live Credentials (Zambia)
  static const String airtelClientId = "your-live-airtel-client-id";
  static const String airtelClientSecret = "your-live-airtel-client-secret";
  static const String airtelBaseUrl = "https://openapi.airtel.africa";
  
  // MTN Mobile Money Live Credentials (Zambia)
  static const String mtnApiKey = "your-live-mtn-api-key";
  static const String mtnApiSecret = "your-live-mtn-api-secret";
  static const String mtnSubscriptionKey = "your-mtn-subscription-key";
  static const String mtnBaseUrl = "https://sandbox.momodeveloper.mtn.com"; // Change to live URL
  
  // Company phone numbers for receiving payments
  static const String airtelCompanyNumber = "0973644384";
  static const String mtnCompanyNumber = "0964536477";
  
  // Payment environment
  static const bool isTestMode = true; // Set to false for live payments

  // Resend email service
  static const String resendApiKey = "your-resend-api-key-here";
  static const String fromEmail = "donations@church-link.app";
}

/*
SETUP INSTRUCTIONS:

1. FLUTTERWAVE SETUP:
   - Go to https://flutterwave.com/
   - Create account and get verified
   - Get your live API keys from dashboard
   - Replace the keys above

2. AIRTEL MONEY SETUP:
   - Contact Airtel Money business team in Zambia
   - Apply for merchant account
   - Get API credentials
   - Replace credentials above

3. MTN MOBILE MONEY SETUP:
   - Contact MTN Mobile Money business team in Zambia
   - Apply for merchant account
   - Get API credentials and subscription key
   - Replace credentials above

4. TESTING:
   - Keep isTestMode = true for testing
   - Set isTestMode = false for live payments
   - Test with small amounts first

5. SECURITY:
   - Never commit real credentials to version control
   - Use environment variables in production
   - Implement proper error handling
*/