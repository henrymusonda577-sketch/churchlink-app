import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/church_service.dart';
import 'services/user_service.dart';

class ChurchDiscovery extends StatefulWidget {
  final Map<String, String> userInfo;

  const ChurchDiscovery({super.key, required this.userInfo});

  @override
  State<ChurchDiscovery> createState() => _ChurchDiscoveryState();
}

class _ChurchDiscoveryState extends State<ChurchDiscovery> {
  final ChurchService _churchService = ChurchService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _userChurchId;
  String? _userChurchRole;

  @override
  void initState() {
    super.initState();
    _loadUserChurchInfo();
  }

  Future<void> _loadUserChurchInfo() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final userDoc = await _userService.getUserById(currentUser.uid);
      if (userDoc != null) {
        setState(() {
          _userChurchId = userDoc['churchId'];
          _userChurchRole = userDoc['churchRole'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Church'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        actions: [
          if (_userChurchId != null)
            IconButton(
              icon: const Icon(Icons.church),
              onPressed: () {
                // TODO: Navigate to user's church
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Your church profile coming soon!')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _buildChurchList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_userChurchId == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Find Your Church',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search for your church and join as a member or register as a visitor',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search churches by name or denomination...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChurchList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _churchService.searchChurches(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading churches'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final churches = snapshot.data!.docs;

        if (churches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.church_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No churches found'
                      : 'No churches match your search',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isEmpty
                      ? 'Be the first to add your church!'
                      : 'Try a different search term',
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: churches.length,
          itemBuilder: (context, index) {
            final churchData = churches[index].data() as Map<String, dynamic>;
            return _buildChurchCard(churches[index].id, churchData);
          },
        );
      },
    );
  }

  Widget _buildChurchCard(String churchId, Map<String, dynamic> churchData) {
    final isUserChurch = churchId == _userChurchId;
    final userRole = _userChurchRole;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Church image
          if (churchData['churchImageUrl'] != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                churchData['churchImageUrl'],
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Church header
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      ),
                      child: churchData['churchLogoUrl'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                churchData['churchLogoUrl'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.church,
                              size: 30,
                              color: Color(0xFF1E3A8A),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  churchData['churchName'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isUserChurch)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Text(
                                    userRole == 'pastor'
                                        ? 'Your Church (Pastor)'
                                        : 'Your Church',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            churchData['denomination'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Church description
                if (churchData['description'] != null)
                  Text(
                    churchData['description'],
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 16),

                // Church info
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        churchData['address'],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${churchData['memberCount']} members',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${(churchData['services'] as List<dynamic>).length} services',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons
                if (!isUserChurch) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showJoinChurchDialog(churchId, churchData),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Join as Member'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            side: const BorderSide(color: Color(0xFF1E3A8A)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _showVisitorDialog(churchId, churchData),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Register as Visitor'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      'You are a member of this church',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinChurchDialog(String churchId, Map<String, dynamic> churchData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Join Church'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Would you like to join ${churchData['churchName']} as a member?'),
              const SizedBox(height: 16),
              const Text(
                'As a member, you will have access to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Church announcements and updates'),
              const Text('• Member directory'),
              const Text('• Church events and activities'),
              const Text('• Community features'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _churchService.joinChurch(churchId);
                Navigator.of(context).pop();
                await _loadUserChurchInfo();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Welcome to ${churchData['churchName']}!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Join Church'),
            ),
          ],
        );
      },
    );
  }

  void _showVisitorDialog(String churchId, Map<String, dynamic> churchData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Register as Visitor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Would you like to register as a visitor at ${churchData['churchName']}?'),
              const SizedBox(height: 16),
              const Text(
                'As a visitor, you will:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Be notified to the pastor'),
              const Text('• Receive church updates'),
              const Text('• Be able to join as a member later'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'The pastor will be notified and may send you an invitation to join as a member.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _churchService.registerAsVisitor(churchId);
                Navigator.of(context).pop();
                await _loadUserChurchInfo();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Registered as visitor at ${churchData['churchName']}!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Register as Visitor'),
            ),
          ],
        );
      },
    );
  }
}


