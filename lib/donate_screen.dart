import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/donation_service.dart';
import 'services/church_service.dart';
import 'widgets/zambian_phone_input.dart';

class DonateScreen extends StatefulWidget {
  final Map<String, String> userInfo;

  const DonateScreen({super.key, required this.userInfo});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  final _pinController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedPurpose = 'Church';
  String _selectedPaymentMethod = 'Visa/Mastercard';
  String _selectedDonationType = 'Tithe'; // Default donation type
  final DonationService _donationService = DonationService();
  final ChurchService _churchService = ChurchService();
  bool _isProcessing = false;

  // Church-related state
  String? _userChurchId;
  String? _userChurchName;
  List<Map<String, dynamic>> _availableChurches = [];
  String? _selectedChurchId;
  bool _isLoadingChurches = false;

  // Loading and error states
  bool _isLoading = true;
  String? _errorMessage;

  // Donation history states
  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _donationHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Listen to tab changes
    _tabController.addListener(_onTabChanged);
    // Load data asynchronously to prevent blank screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void didUpdateWidget(DonateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if userInfo changed
    if (oldWidget.userInfo != widget.userInfo) {
      _initializeData();
    }
  }

  // Load donation history when history tab is selected
  void _onTabChanged() {
    if (_tabController.index == 1 && widget.userInfo['role'] != 'Pastor') {
      _loadDonationHistory();
    }
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedPurpose == 'Church') {
        await _loadUserChurch();
        await _loadAvailableChurches();
      }
    } catch (e) {
      print('Error initializing donate screen: $e');
      setState(() {
        _errorMessage = 'Failed to load donation data. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    _pinController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPastor = widget.userInfo['role'] == 'Pastor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donations'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Give'),
            Tab(text: isPastor ? 'Manage' : 'History'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGiveTab(),
            isPastor ? _buildManageTab() : _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildGiveTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading donation options...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Donation Purpose
          const Text(
            'Select Donation Purpose',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPurposeCard(
              'Church', 'Support your local church', Icons.church),
          const SizedBox(height: 8),
          _buildPurposeCard(
              'App Support', 'Support the app development team', Icons.apps),

          const SizedBox(height: 24),

          // Amount Input
          const Text(
            'Amount',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter Amount (ZMW)',
              prefixText: 'ZMW ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Amount Buttons
          const Text(
            'Quick Amount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickAmountButton('ZMW 50'),
              _buildQuickAmountButton('ZMW 100'),
              _buildQuickAmountButton('ZMW 250'),
              _buildQuickAmountButton('ZMW 500'),
              _buildQuickAmountButton('ZMW 1000'),
              _buildQuickAmountButton('ZMW 2500'),
            ],
          ),

          const SizedBox(height: 24),

          // Payment Method
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodCard('Airtel Money', Icons.phone_android),
          const SizedBox(height: 8),
          _buildPaymentMethodCard('MTN Mobile Money', Icons.phone_android),

          const SizedBox(height: 24),

          // Mobile Money Inputs
          if (_selectedPaymentMethod == 'Airtel Money' ||
              _selectedPaymentMethod == 'MTN Mobile Money') ...[
            const Text(
              'Phone Number',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ZambianPhoneInput(
              controller: _phoneController,
              labelText: null,
            ),
            const SizedBox(height: 24),
            const Text(
              'Mobile Money PIN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your mobile money PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Optional Message
          const Text(
            'Optional Message',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Add a personal message (optional)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 32),

          // Donate Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processDonation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Donate Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeCard(String title, String subtitle, IconData icon) {
    final isSelected = _selectedPurpose == title;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, isSelected ? -5 : 0, 0),
          child: Card(
            color: isSelected ? const Color(0xFF1E3A8A) : null,
            elevation: isSelected ? 8 : 1,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPurpose = title;
                  if (title == 'Church') {
                    _loadUserChurch();
                    _loadAvailableChurches();
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        icon,
                        key: ValueKey<bool>(isSelected),
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            child: Text(title),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : Colors.grey,
                              fontSize: 14,
                            ),
                            child: Text(subtitle),
                          ),
                        ],
                      ),
                    ),
                    isSelected
                        ? const Icon(Icons.check_circle, color: Colors.white)
                        : const SizedBox(width: 24, height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isSelected && title == 'Church') ...[
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: _buildChurchSelectionWidget(),
          ),
          const SizedBox(height: 16),
          AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 300),
            child: _buildDonationTypeSelectionWidget(),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _amountController.text = amount.replaceAll('ZMW ', '');
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black87,
      ),
      child: Text(amount),
    );
  }

  Widget _buildPaymentMethodCard(String title, IconData icon) {
    final isSelected = _selectedPaymentMethod == title;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      transform: Matrix4.translationValues(0, isSelected ? -5 : 0, 0),
      child: Card(
        color: isSelected ? const Color(0xFF1E3A8A) : null,
        elevation: isSelected ? 8 : 1,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedPaymentMethod = title;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    icon,
                    key: ValueKey<bool>(isSelected),
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    child: Text(title),
                  ),
                ),
                isSelected
                    ? const Icon(Icons.check_circle, color: Colors.white)
                    : const SizedBox(width: 24, height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManageTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        final amount = (index + 1) * 25.0;
        final donor = 'Donor ${index + 1}';
        final date = DateTime.now().subtract(Duration(days: index));
        final donationType = index % 2 == 0 ? 'Tithe' : 'Offering';
        final donation = {
          'donor': donor,
          'amount': amount,
          'date': date,
          'purpose': 'Church',
          'donation_type': donationType,
          'payment_method': 'Unknown',
          'status': 'completed',
        };

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E3A8A),
              child: Text(
                'D${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(donor),
            subtitle: Text('${date.day}/${date.month}/${date.year}'),
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    donationType,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            onTap: () => _showDonationDetails(donation, amount, date),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading donation history...'),
          ],
        ),
      );
    }

    if (_donationHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No donations yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your donation history will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(0); // Switch to Give tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Make Your First Donation'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDonationHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _donationHistory.length,
        itemBuilder: (context, index) {
          final donation = _donationHistory[index];
          final amount = donation['amount'] as num? ?? 0;
          final purpose = donation['purpose'] as String? ?? 'Donation';
          final donationType = donation['donation_type'] as String?;
          final paymentMethod = donation['payment_method'] as String? ?? 'Unknown';
          final status = donation['status'] as String? ?? 'completed';
          final createdAt = donation['created_at'] as String?;
          final churchName = donation['church_name'] as String?;

          // Parse date
          DateTime? date;
          if (createdAt != null) {
            try {
              date = DateTime.parse(createdAt);
            } catch (e) {
              date = null;
            }
          }

          // Determine icon based on purpose and type
          IconData iconData;
          if (purpose == 'App Support') {
            iconData = Icons.apps;
          } else if (donationType == 'Tithe') {
            iconData = Icons.account_balance_wallet;
          } else {
            iconData = Icons.favorite;
          }

          // Status color
          Color statusColor;
          switch (status) {
            case 'completed':
              statusColor = Colors.green;
              break;
            case 'pending':
              statusColor = Colors.orange;
              break;
            case 'failed':
              statusColor = Colors.red;
              break;
            default:
              statusColor = Colors.grey;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor,
                child: Icon(
                  iconData,
                  color: Colors.white,
                ),
              ),
              title: Text(
                donationType != null && donationType.isNotEmpty
                    ? donationType
                    : purpose,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (churchName != null && churchName.isNotEmpty)
                    Text(
                      churchName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  Text(
                    date != null
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Date unknown',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    paymentMethod,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              trailing: SizedBox(
                width: 100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ZMW ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                      textAlign: TextAlign.right,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () => _showDonationDetails(
                donation,
                amount.toDouble(),
                date,
              ),
            ),
          );
        },
      ),
    );
  }

  void _processDonation() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Validate church selection if purpose is Church
    if (_selectedPurpose == 'Church' && _selectedChurchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a church for your donation')),
      );
      return;
    }

    // Validate PIN for mobile money payments
    if ((_selectedPaymentMethod == 'Airtel Money' ||
            _selectedPaymentMethod == 'MTN Mobile Money') &&
        _pinController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile money PIN')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Prepare donation data
      final donationData = {
        'amount': amount,
        'currency': 'ZMW',
        'paymentMethod': _selectedPaymentMethod,
        'purpose': _selectedPurpose,
        'donationType': _selectedPurpose == 'Church' ? _selectedDonationType : null,
        'message': _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        'churchId': _selectedChurchId,
        'churchName': _getSelectedChurchName(),
        'userId': Supabase.instance.client.auth.currentUser?.id,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _donationService.initiatePayment(
        context: context,
        amount: amount,
        currency: 'ZMW',
        paymentMethod: _selectedPaymentMethod,
        purpose: _selectedPurpose,
        donationType: _selectedPurpose == 'Church' ? _selectedDonationType : null,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        churchId: _selectedChurchId,
        churchName: _getSelectedChurchName(),
        pin: _pinController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty ? '+260${_phoneController.text.trim()}' : null,
      );

      if (response != null && response['status'] == 'success') {
        _showSuccessDialog();
        _amountController.clear();
        _messageController.clear();
        // Reset church selection
        setState(() {
          _selectedChurchId = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showDonationDialog() {
    final amount =
        _amountController.text.isEmpty ? '0' : _amountController.text;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Donation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Purpose: $_selectedPurpose'),
              const SizedBox(height: 8),
              Text('Amount: ZMW $amount'),
              const SizedBox(height: 8),
              Text('Payment: $_selectedPaymentMethod'),
              const SizedBox(height: 16),
              const Text(
                'This donation will be processed securely. Thank you for your generosity!',
                style: TextStyle(fontSize: 14),
              ),
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
                _processDonation();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    if (_selectedPurpose == 'App Support') {
      _showAppSupportSuccessDialog();
    } else {
      _showRegularSuccessDialog();
    }
  }

  void _showRegularSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thank You!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
              SizedBox(height: 16),
              Text(
                'Your donation has been processed successfully. Thank you for your generosity and support!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _amountController.clear();
                _pinController.clear();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAppSupportSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thank You for Supporting Our Team!'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite,
                color: Colors.red,
                size: 60,
              ),
              SizedBox(height: 16),
              Text(
                'Your donation to support the app development team has been processed successfully. We truly appreciate your generosity!',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Would you like to receive a special "App Supporter" badge to show your support?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _amountController.clear();
                _pinController.clear();
              },
              child: const Text('No Thanks'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _awardSupporterBadge();
                _amountController.clear();
                _pinController.clear();
              },
              child: const Text('Yes, Give Me the Badge!'),
            ),
          ],
        );
      },
    );
  }

  void _awardSupporterBadge() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Add badge to user's profile
        await Supabase.instance.client
            .from('user_badges')
            .insert({
              'user_id': user.id,
              'badge_type': 'app_supporter',
              'badge_name': 'App Supporter',
              'badge_description': 'Donated to support app development',
              'earned_at': DateTime.now().toIso8601String(),
            });

        // Show badge awarded notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 App Supporter badge awarded! Check your profile.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error awarding badge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge awarded!')),
        );
      }
    }
  }

  void _showDonationDetails(Map<String, dynamic> donation, double amount, DateTime? date) {
    final purpose = donation['purpose'] as String? ?? 'Donation';
    final donationType = donation['donation_type'] as String?;
    final paymentMethod = donation['payment_method'] as String? ?? 'Unknown';
    final status = donation['status'] as String? ?? 'completed';
    final message = donation['message'] as String?;
    final churchName = donation['church_name'] as String?;
    final transactionId = donation['transaction_id'] as String?;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Donation Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Purpose: $purpose'),
                const SizedBox(height: 8),
                if (donationType != null && donationType.isNotEmpty)
                  Text('Type: $donationType'),
                if (donationType != null && donationType.isNotEmpty)
                  const SizedBox(height: 8),
                Text('Amount: ZMW ${amount.toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                Text('Payment Method: $paymentMethod'),
                const SizedBox(height: 8),
                if (churchName != null && churchName.isNotEmpty) ...[
                  Text('Church: $churchName'),
                  const SizedBox(height: 8),
                ],
                Text('Date: ${date != null ? '${date.day}/${date.month}/${date.year}' : 'Unknown'}'),
                const SizedBox(height: 8),
                Text('Status: ${status.toUpperCase()}'),
                if (transactionId != null && transactionId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Transaction ID: $transactionId'),
                ],
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('"$message"'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (status == 'completed')
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showFeatureDialog(
                      'Send Receipt', 'Receipt feature coming soon');
                },
                child: const Text('Send Receipt'),
              ),
          ],
        );
      },
    );
  }

  void _showFeatureDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Build donation type selection widget
  Widget _buildDonationTypeSelectionWidget() {
    final donationTypes = ['Tithe', 'Offering', 'Building Fund', 'Custom'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Donation Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: donationTypes.map((type) {
              final isSelected = _selectedDonationType == type;
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedDonationType = type;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
                  foregroundColor: isSelected ? Colors.white : Colors.black87,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[300]!,
                  ),
                ),
                child: Text(type),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Build church selection widget
  Widget _buildChurchSelectionWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Church for Donation',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // User's joined church
          if (_userChurchName != null) ...[
            const Text(
              'Your Church:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: _selectedChurchId == _userChurchId
                  ? const Color(0xFF1E3A8A)
                  : Colors.white,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedChurchId = _userChurchId;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.church,
                        color: _selectedChurchId == _userChurchId
                            ? Colors.white
                            : const Color(0xFF1E3A8A),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userChurchName!,
                              style: TextStyle(
                                color: _selectedChurchId == _userChurchId
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Your joined church',
                              style: TextStyle(
                                color: _selectedChurchId == _userChurchId
                                    ? Colors.white70
                                    : Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _selectedChurchId == _userChurchId
                          ? const Icon(Icons.check_circle, color: Colors.white)
                          : const SizedBox(width: 24, height: 24),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Available churches
          const Text(
            'Available Churches:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),

          if (_isLoadingChurches)
            const Center(child: CircularProgressIndicator())
          else if (_availableChurches.isEmpty)
            const Center(
              child: Text(
                'No churches available',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _availableChurches.length,
                itemBuilder: (context, index) {
                  final church = _availableChurches[index];
                  final churchId = church['id'] as String;
                  final churchName =
                      church['church_name'] as String? ?? 'Unknown Church';
                  final isSelected = _selectedChurchId == churchId;
                  final isUserChurch = churchId == _userChurchId;

                  // Skip user's church as it's already shown above
                  if (isUserChurch) return const SizedBox.shrink();

                  return Card(
                    color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedChurchId = churchId;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.church,
                              color: isSelected ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    churchName,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    church['location'] as String? ??
                                        'Location not specified',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white70 : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            isSelected
                                ? const Icon(Icons.check_circle, color: Colors.white)
                                : const SizedBox(width: 24, height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Selected church info
          if (_selectedChurchId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info,
                    color: Color(0xFF1E3A8A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Donation will be directed to: ${_getSelectedChurchName()}',
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Get selected church name
  String _getSelectedChurchName() {
    if (_selectedChurchId == null) return 'No church selected';

    if (_selectedChurchId == _userChurchId) {
      return _userChurchName ?? 'Your Church';
    }

    final church = _availableChurches.firstWhere(
      (c) => c['id'] == _selectedChurchId,
      orElse: () => <String, dynamic>{},
    );

    return church['church_name'] as String? ?? 'Unknown Church';
  }

  // Load user's church membership
  Future<void> _loadUserChurch() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('users')
            .select('church_id, church_name')
            .eq('id', user.id)
            .single();

        setState(() {
          _userChurchId = response['church_id'];
          _userChurchName = response['church_name'];
        });
      }
    } catch (e) {
      print('Error loading user church: $e');
      // Don't show error snackbar here as it might cause issues during init
    }
  }

  // Load all available churches
  Future<void> _loadAvailableChurches() async {
    if (_isLoadingChurches) return;

    setState(() {
      _isLoadingChurches = true;
    });

    try {
      final response = await Supabase.instance.client
          .from('churches')
          .select('id, church_name, location')
          .order('church_name');

      final churches = response as List<dynamic>;

      setState(() {
        _availableChurches = List<Map<String, dynamic>>.from(churches);
      });
    } catch (e) {
      print('Error loading churches: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading churches: $e')),
      );
    } finally {
      setState(() {
        _isLoadingChurches = false;
      });
    }
  }

  // Load user's donation history
  Future<void> _loadDonationHistory() async {
    if (_isLoadingHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('donations')
          .select('*')
          .eq('user_id', user.id)
          .order('donated_at', ascending: false);

      final donations = response as List<dynamic>;

      setState(() {
        _donationHistory = List<Map<String, dynamic>>.from(donations);
      });
    } catch (e) {
      print('Error loading donation history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading donation history: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }
}
