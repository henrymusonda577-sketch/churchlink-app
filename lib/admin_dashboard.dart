import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'services/church_payout_service.dart';
import 'services/user_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final ChurchPayoutService _payoutService = ChurchPayoutService();
  final UserService _userService = UserService();
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildPayoutManagementTab(),
          _buildAnalyticsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'Payouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutManagementTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getPendingPayouts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final payouts = snapshot.data ?? [];

        if (payouts.isEmpty) {
          return const Center(child: Text('No pending payouts'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payouts.length,
          itemBuilder: (context, index) {
            final payout = payouts[index];
            final amount = (payout['amount'] as num?)?.toDouble() ?? 0.0;
            final churchName = payout['church_name'] ?? 'Unknown Church';
            final createdAt = payout['created_at'] as String?;
            final reference = payout['reference'] as String?;
            final accountDetails = payout['account_details'] as Map<String, dynamic>?;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          churchName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ZMW ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    if (reference != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reference: ${reference.substring(0, min(20, reference.length))}...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Requested: ${_formatTimestamp(createdAt)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (accountDetails != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Details:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Account Name: ${accountDetails['account_name'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'Account Number: ${accountDetails['account_number'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            if (accountDetails['bank_name'] != null) ...[
                              Text(
                                'Bank: ${accountDetails['bank_name']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            if (accountDetails['mobile_provider'] != null) ...[
                              Text(
                                'Mobile Provider: ${accountDetails['mobile_provider']}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            Text(
                              'Type: ${accountDetails['account_type'] == 'bank' ? 'Bank Account' : 'Mobile Money'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _markPayoutCompleted(payout['id']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Mark as Completed'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getAnalyticsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final analytics = snapshot.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Platform Analytics',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Key Metrics Row
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Total Users',
                      '${analytics['total_users'] ?? 0}',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Active Churches',
                      '${analytics['active_churches'] ?? 0}',
                      Icons.church,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Total Donations',
                      'ZMW ${(analytics['total_donations'] ?? 0).toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAnalyticsCard(
                      'Total Payouts',
                      'ZMW ${(analytics['total_payouts'] ?? 0).toStringAsFixed(2)}',
                      Icons.payment,
                      Colors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Financial Summary
              const Text(
                'Financial Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildFinancialRow(
                        'Platform Revenue (10%)',
                        'ZMW ${(analytics['platform_revenue'] ?? 0).toStringAsFixed(2)}',
                        Colors.green,
                      ),
                      const Divider(),
                      _buildFinancialRow(
                        'Church Distributions (90%)',
                        'ZMW ${(analytics['church_distributions'] ?? 0).toStringAsFixed(2)}',
                        Colors.blue,
                      ),
                      const Divider(),
                      _buildFinancialRow(
                        'Pending Payouts',
                        'ZMW ${(analytics['pending_payouts'] ?? 0).toStringAsFixed(2)}',
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recent Activity
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              if ((analytics['recent_donations'] as List?)?.isEmpty ?? true)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No recent donations'),
                  ),
                )
              else
                ...((analytics['recent_donations'] as List?) ?? []).take(5).map((donation) {
                  final amount = (donation['amount'] as num?)?.toDouble() ?? 0;
                  final churchName = donation['church_name'] ?? 'Unknown Church';
                  final createdAt = donation['created_at'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.volunteer_activism, color: Colors.green),
                      title: Text('ZMW ${amount.toStringAsFixed(2)} donation'),
                      subtitle: Text('$churchName • ${_formatTimestamp(createdAt)}'),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Top Churches
              const Text(
                'Top Performing Churches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              if ((analytics['top_churches'] as List?)?.isEmpty ?? true)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No church data available'),
                  ),
                )
              else
                ...((analytics['top_churches'] as List?) ?? []).take(5).map((church) {
                  final name = church['church_name'] ?? 'Unknown';
                  final donations = (church['total_donations'] as num?)?.toDouble() ?? 0;
                  final members = church['member_count'] ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.church, color: Color(0xFF1E3A8A)),
                      title: Text(name),
                      subtitle: Text('$members members • ZMW ${donations.toStringAsFixed(2)} raised'),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getPendingPayouts() async {
    try {
      final response = await Supabase.instance.client
          .from('payout_history')
          .select('*, churches!inner(church_name), church_payout_accounts(*)')
          .eq('status', 'pending')
          .eq('method', 'manual')
          .order('created_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);

      // Enrich the data with proper structure
      final enriched = <Map<String, dynamic>>[];
      for (final payout in data) {
        final enrichedPayout = Map<String, dynamic>.from(payout);
        enrichedPayout['church_name'] = payout['churches']?['church_name'] ?? 'Unknown Church';
        enrichedPayout['account_details'] = payout['church_payout_accounts'];
        enriched.add(enrichedPayout);
      }

      return enriched;
    } catch (e) {
      print('Error getting pending payouts: $e');
      return [];
    }
  }

  Future<void> _markPayoutCompleted(String payoutId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await _payoutService.markPayoutCompleted(payoutId, user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getAnalyticsData() async {
    try {
      // Get counts separately
      final usersResponse = await Supabase.instance.client.from('users').select('id').count(CountOption.exact);
      final churchesResponse = await Supabase.instance.client.from('churches').select('id').count(CountOption.exact);

      final results = await Future.wait([
        // Total donations
        Supabase.instance.client.from('donations').select('amount').eq('status', 'completed'),

        // Total payouts
        Supabase.instance.client.from('payout_history').select('amount').eq('status', 'successful'),

        // Pending payouts
        Supabase.instance.client.from('payout_history').select('amount').eq('status', 'pending').eq('method', 'manual'),

        // Recent donations
        Supabase.instance.client
            .from('donations')
            .select('*, churches!inner(church_name)')
            .eq('status', 'completed')
            .order('created_at', ascending: false)
            .limit(10),

        // Top churches by donations
        Supabase.instance.client
            .from('churches')
            .select('*, donations!inner(amount)')
            .eq('donations.status', 'completed'),
      ]);

      // Process results
      final usersCount = usersResponse.count ?? 0;
      final churchesCount = churchesResponse.count ?? 0;

      final donations = List<Map<String, dynamic>>.from(results[0] as List);
      final totalDonations = donations.fold<double>(0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0));

      final payouts = List<Map<String, dynamic>>.from(results[1] as List);
      final totalPayouts = payouts.fold<double>(0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

      final pendingPayouts = List<Map<String, dynamic>>.from(results[2] as List);
      final pendingAmount = pendingPayouts.fold<double>(0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

      final recentDonations = List<Map<String, dynamic>>.from(results[3] as List);

      // Process top churches
      final churchesData = List<Map<String, dynamic>>.from(results[4] as List);
      final churchStats = <String, Map<String, dynamic>>{};

      for (final church in churchesData) {
        final churchId = church['id'] as String;
        final churchName = church['church_name'] as String;
        final memberCount = church['member_count'] ?? 0;

        if (!churchStats.containsKey(churchId)) {
          churchStats[churchId] = {
            'church_name': churchName,
            'member_count': memberCount,
            'total_donations': 0.0,
          };
        }

        // Sum up donations for this church
        final churchDonations = church['donations'] as List?;
        if (churchDonations != null) {
          for (final donation in churchDonations) {
            churchStats[churchId]!['total_donations'] += (donation['amount'] as num?)?.toDouble() ?? 0;
          }
        }
      }

      final topChurches = churchStats.values.toList()
        ..sort((a, b) => (b['total_donations'] as double).compareTo(a['total_donations'] as double));

      return {
        'total_users': usersCount,
        'active_churches': churchesCount,
        'total_donations': totalDonations,
        'total_payouts': totalPayouts,
        'platform_revenue': totalDonations * 0.1,
        'church_distributions': totalDonations * 0.9,
        'pending_payouts': pendingAmount,
        'recent_donations': recentDonations,
        'top_churches': topChurches,
      };
    } catch (e) {
      print('Error getting analytics data: $e');
      return {
        'total_users': 0,
        'active_churches': 0,
        'total_donations': 0.0,
        'total_payouts': 0.0,
        'platform_revenue': 0.0,
        'church_distributions': 0.0,
        'pending_payouts': 0.0,
        'recent_donations': [],
        'top_churches': [],
      };
    }
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(String label, String amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}