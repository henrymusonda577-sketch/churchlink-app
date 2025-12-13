import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeeBanner extends StatefulWidget {
  final double amount;

  const FeeBanner({super.key, required this.amount});

  @override
  State<FeeBanner> createState() => _FeeBannerState();
}

class _FeeBannerState extends State<FeeBanner> {
  String _userTier = 'basic';
  double _adminFee = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserTier();
  }

  @override
  void didUpdateWidget(FeeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      _calculateFee();
    }
  }

  Future<void> _loadUserTier() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .rpc('get_user_tier', params: {'p_user_id': user.id});

        if (response != null) {
          setState(() {
            _userTier = response as String;
          });
          _calculateFee();
        }
      }
    } catch (e) {
      print('Error loading user tier: $e');
    }
  }

  void _calculateFee() {
    double feePercentage = 0.10; // Default 10%

    switch (_userTier) {
      case 'basic':
        feePercentage = 0.10; // 10%
        break;
      case 'pro':
        feePercentage = 0.05; // 5%
        break;
      case 'kingdom':
        feePercentage = 0.00; // 0%
        break;
    }

    setState(() {
      _adminFee = (widget.amount * feePercentage).roundToDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(
            _userTier == 'kingdom' ? Icons.star : Icons.info,
            color: Colors.blue[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Admin fee: ZMW ${_adminFee.toStringAsFixed(2)} (${_getTierText()})',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (_userTier != 'kingdom') ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                // Navigate to upgrade screen
                _showUpgradeDialog();
              },
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTierText() {
    switch (_userTier) {
      case 'basic':
        return '10% for Basic users';
      case 'pro':
        return '5% for Pro users';
      case 'kingdom':
        return '0% for Kingdom users';
      default:
        return '10%';
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Your Tier'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reduce your admin fees by upgrading:'),
            SizedBox(height: 8),
            Text('• Pro: 5% fee (ZMW 20/month)'),
            Text('• Kingdom: 0% fee (ZMW 50/month) + Priority support'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to subscription screen
              _navigateToSubscription();
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _navigateToSubscription() {
    // TODO: Navigate to subscription management screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscription management coming soon!')),
    );
  }
}