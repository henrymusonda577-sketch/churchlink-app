import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/event_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventService _eventService = EventService();
  String _selectedFilter = 'All';
  final Map<String, bool> _userAttendance = {};

  @override
  void initState() {
    super.initState();
    _loadUserAttendance();
  }

  Future<void> _loadUserAttendance() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final events = await _eventService.getEvents().first;
      for (final event in events) {
        final isAttending = await _eventService.isUserAttending(event['id'], currentUserId);
        if (mounted) {
          setState(() {
            _userAttendance[event['id']] = isAttending;
          });
        }
      }
    } catch (e) {
      print('Error loading user attendance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: const Text('Church Events'),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _eventService.getEvents(eventType: _selectedFilter == 'All' ? null : _selectedFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 80, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading events',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final events = snapshot.data ?? [];

                if (events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event, size: 80, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 20),
                        Text(
                          'No events found',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tap + to create your first event',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _buildEventCard(event);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateEventDialog,
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterSection() {
    final filters = ['All', 'Service', 'Study', 'Youth', 'Prayer', 'Social'];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              selectedColor: const Color(0xFF1E3A8A),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.grey[200],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventId = event['id'];
    final date = DateTime.parse(event['event_date']);
    final isToday = DateTime.now().day == date.day && DateTime.now().month == date.month && DateTime.now().year == date.year;
    final attendees = List<String>.from(event['attendees'] ?? []);
    final isAttending = _userAttendance[eventId] ?? attendees.contains(Supabase.instance.client.auth.currentUser?.id ?? '');
    final maxAttendees = event['max_attendees'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEventDetails(event),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getEventColor(event['event_type']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getEventIcon(event['event_type']),
                      color: _getEventColor(event['event_type']).withValues(alpha: 1.0),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event['description'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatDate(date)} • ${event['event_time'] ?? 'TBD'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const Spacer(),
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    event['location'] ?? 'TBD',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${attendees.length}${maxAttendees != null ? '/$maxAttendees' : ''} attending',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _toggleAttendance(event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAttending ? Colors.green : const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      isAttending ? 'Attending' : 'Join',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEventColor(String type) {
    switch (type) {
      case 'service':
        return const Color(0xFF1E3A8A);
      case 'study':
        return Colors.green;
      case 'youth':
        return Colors.orange;
      case 'prayer':
        return Colors.red;
      case 'social':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'service':
        return Icons.church;
      case 'study':
        return Icons.book;
      case 'youth':
        return Icons.group;
      case 'prayer':
        return Icons.favorite;
      case 'social':
        return Icons.celebration;
      default:
        return Icons.event;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7 && diff > 0) return '${diff} days';
    if (diff == -1) return 'Yesterday';
    if (diff > -7 && diff < 0) return '${diff.abs()} days ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  void _showEventDetails(Map<String, dynamic> event) {
    final eventId = event['id'];
    final date = DateTime.parse(event['event_date']);
    final attendees = List<String>.from(event['attendees'] ?? []);
    final maxAttendees = event['max_attendees'] as int?;
    final isAttending = _userAttendance[eventId] ?? attendees.contains(Supabase.instance.client.auth.currentUser?.id ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event['description'] ?? ''),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text('${_formatDate(date)} at ${event['event_time'] ?? 'TBD'}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 8),
                Text(event['location'] ?? 'TBD'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16),
                const SizedBox(width: 8),
                Text('${attendees.length}${maxAttendees != null ? '/$maxAttendees' : ''} people attending'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _getEventIcon(event['event_type']),
                  size: 16,
                  color: _getEventColor(event['event_type']),
                ),
                const SizedBox(width: 8),
                Text(
                  event['event_type'].toString().toUpperCase(),
                  style: TextStyle(
                    color: _getEventColor(event['event_type']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleAttendance(event);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAttending ? Colors.green : const Color(0xFF1E3A8A),
            ),
            child: Text(isAttending ? 'Leave Event' : 'Join Event'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAttendance(Map<String, dynamic> event) async {
    final eventId = event['id'];
    final eventTitle = event['title'];
    final attendees = List<String>.from(event['attendees'] ?? []);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final wasAttending = attendees.contains(currentUserId);

    try {
      await _eventService.toggleAttendance(eventId);

      // Update local state
      final isNowAttending = await _eventService.isUserAttending(eventId, currentUserId);
      setState(() {
        _userAttendance[eventId] = isNowAttending;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasAttending ? 'Left ${eventTitle}' : 'Joined ${eventTitle}!'),
          backgroundColor: wasAttending ? Colors.orange : const Color(0xFF1E3A8A),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    final timeController = TextEditingController();
    String selectedType = 'service';
    DateTime selectedDate = DateTime.now();
    int? maxAttendees;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Event Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'service', child: Text('Service')),
                    DropdownMenuItem(value: 'study', child: Text('Study')),
                    DropdownMenuItem(value: 'youth', child: Text('Youth')),
                    DropdownMenuItem(value: 'prayer', child: Text('Prayer')),
                    DropdownMenuItem(value: 'social', child: Text('Social')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time (e.g., 9:00 AM)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('Date: ${selectedDate.toString().split(' ')[0]}'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: const Text('Select Date'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Max Attendees (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    maxAttendees = value.isEmpty ? null : int.tryParse(value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title')),
                  );
                  return;
                }

                try {
                  await _eventService.createEvent(
                    title: titleController.text,
                    description: descriptionController.text,
                    eventType: selectedType,
                    eventDate: selectedDate,
                    eventTime: timeController.text,
                    location: locationController.text,
                    maxAttendees: maxAttendees,
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Event created successfully!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating event: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
