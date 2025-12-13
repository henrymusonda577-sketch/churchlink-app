import 'package:flutter/material.dart';
import '../services/reading_plan_service.dart';

class ReadingPlanScreen extends StatefulWidget {
  const ReadingPlanScreen({super.key});

  @override
  State<ReadingPlanScreen> createState() => _ReadingPlanScreenState();
}

class _ReadingPlanScreenState extends State<ReadingPlanScreen> {
  final ReadingPlanService _readingPlanService = ReadingPlanService();
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _currentPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final plans = await _readingPlanService.getAvailablePlans();
      final currentPlan = await _readingPlanService.getCurrentPlanProgress();

      setState(() {
        _plans = plans;
        _currentPlan = currentPlan;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading reading plans: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Plans'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        if (_currentPlan != null) _buildCurrentPlanCard(),
        Expanded(
          child: _buildPlansList(),
        ),
      ],
    );
  }

  Widget _buildCurrentPlanCard() {
    final progress =
        (_currentPlan!['completedDays'] / _currentPlan!['totalDays'] * 100)
            .round();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current Plan: ${_currentPlan!['planName']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Day ${_currentPlan!['currentDay']} of ${_currentPlan!['totalDays']}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            Text('$progress% Complete'),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _navigateToTodayReading(),
                  child: const Text('Read Today'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showPlanOptions(),
                  child: const Text('Options'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlansList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              _getPlanIcon(plan['category']),
              color: Theme.of(context).primaryColor,
            ),
            title: Text(
              plan['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['description']),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildDifficultyChip(plan['difficulty']),
                    const SizedBox(width: 8),
                    Text('${plan['duration']} days'),
                  ],
                ),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _startPlan(plan),
              child: const Text('Start'),
            ),
            onTap: () => _showPlanDetails(plan),
          ),
        );
      },
    );
  }

  IconData _getPlanIcon(String category) {
    switch (category) {
      case 'yearly':
        return Icons.calendar_today;
      case 'quarterly':
        return Icons.calendar_view_month;
      case 'thematic':
        return Icons.topic;
      default:
        return Icons.book;
    }
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color color;
    switch (difficulty) {
      case 'beginner':
        color = Colors.green;
        break;
      case 'intermediate':
        color = Colors.orange;
        break;
      case 'advanced':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        difficulty,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  void _startPlan(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${plan['name']}?'),
        content: Text(
          'This will ${plan['id'] == _currentPlan?['planId'] ? 'restart' : 'start'} your reading plan. '
          'You will read ${plan['duration']} days worth of material.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _readingPlanService.startReadingPlan(plan['id']);
        await _loadData(); // Refresh data
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Started ${plan['name']}!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting plan: $e')),
        );
      }
    }
  }

  void _navigateToTodayReading() async {
    final todayReading = await _readingPlanService.getTodayReading();
    if (todayReading != null) {
      // Parse the first reading reference
      final firstReading = todayReading['readings'][0] as String;
      final parts = firstReading.split(' ');
      if (parts.length >= 2) {
        final book = parts[0];
        final chapterVerse = parts[1];

        // Navigate to Bible screen with today's reading
        Navigator.of(context).pushNamed(
          '/bible',
          arguments: {
            'book': book,
            'chapter': chapterVerse,
            'translation': 'KJV', // Default translation
          },
        );
      }
    }
  }

  void _showPlanDetails(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan['name'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(plan['description']),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text('${plan['duration']} days'),
                const SizedBox(width: 16),
                _buildDifficultyChip(plan['difficulty']),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startPlan(plan);
                },
                child: const Text('Start This Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlanOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pause),
              title: const Text('Pause Plan'),
              onTap: () async {
                Navigator.of(context).pop();
                await _readingPlanService.pauseReadingPlan();
                await _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reading plan paused')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Resume Plan'),
              onTap: () async {
                Navigator.of(context).pop();
                await _readingPlanService.resumeReadingPlan();
                await _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reading plan resumed')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Restart Plan'),
              onTap: () async {
                Navigator.of(context).pop();
                await _readingPlanService.resetReadingPlan();
                await _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reading plan restarted')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
