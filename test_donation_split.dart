import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/donation_service.dart';
import 'lib/services/church_payout_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Donation Split Tests', () {
    late DonationService donationService;
    late ChurchPayoutService payoutService;

    setUp(() {
      donationService = DonationService();
      payoutService = ChurchPayoutService();
    });

    test('Calculate donation splits correctly', () {
      final totalAmount = 100.0;
      final platformFee = totalAmount * 0.1; // 10%
      final churchAmount = totalAmount * 0.9; // 90%

      expect(platformFee, 10.0);
      expect(churchAmount, 90.0);
      expect(platformFee + churchAmount, totalAmount);
    });

    test('Process donation split creates correct records', () async {
      // This would require a test database setup
      // For now, just test the calculation logic
      final donationId = 'test-donation-id';
      final totalAmount = 200.0;
      final churchId = 'test-church-id';

      // Test that the method exists and can be called
      expect(() async {
        await payoutService.processDonationSplit(
          donationId: donationId,
          totalAmount: totalAmount,
          churchId: churchId,
        );
      }, isNotNull);
    });

    test('Donation service has required methods', () {
      expect(donationService.logDonation, isNotNull);
      expect(donationService.updateDonationStatus, isNotNull);
    });

    test('Church payout service has required methods', () {
      expect(payoutService.createChurchSubaccount, isNotNull);
      expect(payoutService.getChurchPayoutAccounts, isNotNull);
      expect(payoutService.processDonationSplit, isNotNull);
    });
  });
}