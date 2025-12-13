import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/church_payout_service.dart';

class ChurchPayoutSetupScreen extends StatefulWidget {
  final Map<String, dynamic> churchData;

  const ChurchPayoutSetupScreen({super.key, required this.churchData});

  @override
  State<ChurchPayoutSetupScreen> createState() => _ChurchPayoutSetupScreenState();
}

class _ChurchPayoutSetupScreenState extends State<ChurchPayoutSetupScreen> {
  final ChurchPayoutService _payoutService = ChurchPayoutService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankCodeController = TextEditingController();

  String _accountType = 'bank';
  String _mobileProvider = 'airtel';
  List<Map<String, dynamic>> _payoutAccounts = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Zambian bank codes
  final Map<String, String> _zambianBanks = {
    'ZANACO': 'ZANACO',
    'FNB': 'FNBZAM',
    'STANBIC': 'STANBICZAM',
    'ABSA': 'ABSAZAM',
    'INDO': 'INDOZAM',
    'UNION': 'UNIONZAM',
    'ECOBANK': 'ECOBANKZAM',
  };

  @override
  void initState() {
    super.initState();
    _loadPayoutAccounts();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _bankCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadPayoutAccounts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await _payoutService.getChurchPayoutAccounts(widget.churchData['id']);
      setState(() {
        _payoutAccounts = accounts;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payout accounts: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitPayoutAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _payoutService.createChurchSubaccount(
        churchId: widget.churchData['id'],
        accountName: _accountNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        bankCode: _accountType == 'bank' ? _bankCodeController.text.trim() : '',
        bankName: _accountType == 'bank' ? _bankNameController.text.trim() : null,
        mobileProvider: _accountType == 'mobile_money' ? _mobileProvider : null,
      );

      if (result != null) {
        _clearForm();
        _loadPayoutAccounts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payout account added successfully!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add payout account. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _clearForm() {
    _accountNameController.clear();
    _accountNumberController.clear();
    _bankNameController.clear();
    _bankCodeController.clear();
    setState(() {
      _accountType = 'bank';
      _mobileProvider = 'airtel';
    });
  }

  Future<void> _toggleAccountStatus(String accountId, bool currentStatus) async {
    final newStatus = !currentStatus;
    final success = await _payoutService.updatePayoutAccountStatus(accountId, newStatus);

    if (success) {
      _loadPayoutAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account ${newStatus ? 'activated' : 'deactivated'}')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update account status')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Accounts'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Church Payout Setup',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up bank or mobile money accounts to receive donations. Churches receive 90% of donations, platform keeps 10%.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Add new account form
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Payout Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Account type selection
                            const Text('Account Type'),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Text('Bank Account'),
                                    value: 'bank',
                                    groupValue: _accountType,
                                    onChanged: (value) {
                                      setState(() {
                                        _accountType = value!;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: const Text('Mobile Money'),
                                    value: 'mobile_money',
                                    groupValue: _accountType,
                                    onChanged: (value) {
                                      setState(() {
                                        _accountType = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Account name
                            TextFormField(
                              controller: _accountNameController,
                              decoration: const InputDecoration(
                                labelText: 'Account Name',
                                hintText: 'e.g., Church Main Account',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Account name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Account number
                            TextFormField(
                              controller: _accountNumberController,
                              decoration: InputDecoration(
                                labelText: _accountType == 'bank' ? 'Account Number' : 'Phone Number',
                                hintText: _accountType == 'bank' ? 'e.g., 1234567890' : 'e.g., 0977123456',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return _accountType == 'bank' ? 'Account number is required' : 'Phone number is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Bank details (if bank account)
                            if (_accountType == 'bank') ...[
                              TextFormField(
                                controller: _bankNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Name',
                                  hintText: 'e.g., ZANACO, FNB',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Bank name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _bankCodeController.text.isEmpty ? null : _bankCodeController.text,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Code',
                                  border: OutlineInputBorder(),
                                ),
                                items: _zambianBanks.entries.map((entry) {
                                  return DropdownMenuItem(
                                    value: entry.value,
                                    child: Text('${entry.key} (${entry.value})'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _bankCodeController.text = value ?? '';
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Bank code is required';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            // Mobile provider (if mobile money)
                            if (_accountType == 'mobile_money') ...[
                              const Text('Mobile Provider'),
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Airtel Money'),
                                      value: 'airtel',
                                      groupValue: _mobileProvider,
                                      onChanged: (value) {
                                        setState(() {
                                          _mobileProvider = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('MTN Money'),
                                      value: 'mtn',
                                      groupValue: _mobileProvider,
                                      onChanged: (value) {
                                        setState(() {
                                          _mobileProvider = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Submit button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitPayoutAccount,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isSubmitting
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('Add Payout Account'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Existing accounts
                  const Text(
                    'Existing Payout Accounts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_payoutAccounts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No payout accounts set up yet. Add one above to start receiving donations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._payoutAccounts.map((account) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      account['account_type'] == 'bank'
                                          ? Icons.account_balance
                                          : Icons.phone_android,
                                      color: const Color(0xFF1E3A8A),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        account['account_name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: account['is_active'] ? Colors.green : Colors.grey,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        account['is_active'] ? 'Active' : 'Inactive',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  account['account_type'] == 'bank'
                                      ? '${account['bank_name']} - ${account['account_number']}'
                                      : '${account['mobile_provider']} - ${account['account_number']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _toggleAccountStatus(
                                        account['id'],
                                        account['is_active'] ?? false,
                                      ),
                                      child: Text(
                                        account['is_active'] ? 'Deactivate' : 'Activate',
                                        style: TextStyle(
                                          color: account['is_active'] ? Colors.red : Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}