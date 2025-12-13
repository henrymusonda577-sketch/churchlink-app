import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class EventService {
  final SupabaseClient _supabase;

  EventService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  // Create a new event
  Future<void> createEvent({
    required String title,
    required String description,
    required String eventType,
    required DateTime eventDate,
    String? eventTime,
    String? location,
    int? maxAttendees,
    String? imageUrl,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Get user's church_id
      final userData = await _supabase
          .from('users')
          .select('church_id')
          .eq('id', currentUser.id)
          .single();

      final eventData = {
        'user_id': currentUser.id,
        'church_id': userData['church_id'],
        'title': title,
        'description': description,
        'event_type': eventType,
        'event_date': eventDate.toIso8601String(),
        'event_time': eventTime,
        'location': location,
        'max_attendees': maxAttendees,
        'image_url': imageUrl,
        'attendees': [currentUser.id], // Creator automatically attends
      };

      await _supabase.from('events').insert(eventData);
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  // Get all events
  Stream<List<Map<String, dynamic>>> getEvents({String? eventType}) {
    try {
      return _supabase
          .from('events')
          .stream(primaryKey: ['id'])
          .order('event_date', ascending: true)
          .map((data) {
            final events = List<Map<String, dynamic>>.from(data);
            if (eventType != null && eventType != 'All') {
              return events.where((event) => event['event_type'] == eventType.toLowerCase()).toList();
            }
            return events;
          });
    } catch (e) {
      print('Error fetching events: $e');
      return Stream.value([]);
    }
  }

  // Get events for a specific church
  Stream<List<Map<String, dynamic>>> getChurchEvents(String churchId, {String? eventType}) {
    try {
      return _supabase
          .from('events')
          .stream(primaryKey: ['id'])
          .eq('church_id', churchId)
          .order('event_date', ascending: true)
          .map((data) {
            final events = List<Map<String, dynamic>>.from(data);
            if (eventType != null && eventType != 'All') {
              return events.where((event) => event['event_type'] == eventType.toLowerCase()).toList();
            }
            return events;
          });
    } catch (e) {
      print('Error fetching church events: $e');
      return Stream.value([]);
    }
  }

  // Get upcoming events
  Stream<List<Map<String, dynamic>>> getUpcomingEvents() {
    try {
      final now = DateTime.now().toIso8601String();
      return _supabase
          .from('events')
          .stream(primaryKey: ['id'])
          .gte('event_date', now)
          .order('event_date', ascending: true)
          .map((data) => List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('Error fetching upcoming events: $e');
      return Stream.value([]);
    }
  }

  // Toggle attendance for an event
  Future<void> toggleAttendance(String eventId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get current event
      final event = await _supabase.from('events').select('attendees, max_attendees, title, user_id').eq('id', eventId).single();
      final attendees = List<String>.from(event['attendees'] ?? []);
      final maxAttendees = event['max_attendees'] as int?;
      final eventTitle = event['title'];
      final eventOwnerId = event['user_id'];

      final isAttending = attendees.contains(currentUser.id);

      if (isAttending) {
        // Remove from attendees
        attendees.remove(currentUser.id);
      } else {
        // Check if event is full
        if (maxAttendees != null && attendees.length >= maxAttendees) {
          throw Exception('Event is full');
        }
        // Add to attendees
        attendees.add(currentUser.id);
      }

      await _supabase.from('events').update({'attendees': attendees}).eq('id', eventId);

      // Send notification to event owner if someone joins their event
      if (!isAttending && eventOwnerId != currentUser.id) {
        try {
          // Get current user's details for personalized notification
          final userData = await _supabase
              .from('users')
              .select('name, profile_picture_url')
              .eq('id', currentUser.id)
              .single();

          final userName = userData['name'] ?? 'Someone';
          final profilePictureUrl = userData['profile_picture_url'];

          final notificationService = NotificationService();
          await notificationService.sendPushNotification(
            userId: eventOwnerId,
            title: 'New Attendee',
            body: '$userName joined your event: "$eventTitle"',
            data: {
              'eventId': eventId,
              'type': 'event_attendance',
              'attendeeName': userName,
              'attendeeProfilePicture': profilePictureUrl,
              'attendeeId': currentUser.id,
            },
          );
        } catch (e) {
          print('Error sending attendance notification: $e');
        }
      }
    } catch (e) {
      print('Error toggling attendance: $e');
      rethrow;
    }
  }

  // Check if user is attending an event
  Future<bool> isUserAttending(String eventId, String userId) async {
    try {
      final event = await _supabase.from('events').select('attendees').eq('id', eventId).single();
      final attendees = List<String>.from(event['attendees'] ?? []);
      return attendees.contains(userId);
    } catch (e) {
      print('Error checking attendance: $e');
      return false;
    }
  }

  // Get event attendees with user details
  Future<List<Map<String, dynamic>>> getEventAttendees(String eventId) async {
    try {
      final event = await _supabase.from('events').select('attendees').eq('id', eventId).single();
      final attendeeIds = List<String>.from(event['attendees'] ?? []);

      if (attendeeIds.isEmpty) return [];

      final attendees = <Map<String, dynamic>>[];
      for (final userId in attendeeIds) {
        try {
          final userData = await _supabase
              .from('users')
              .select('id, name, profile_picture_url')
              .eq('id', userId)
              .single();
          attendees.add(userData);
        } catch (e) {
          print('Error getting attendee data for $userId: $e');
        }
      }

      return attendees;
    } catch (e) {
      print('Error getting event attendees: $e');
      return [];
    }
  }

  // Update event
  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if user owns the event
      final event = await _supabase.from('events').select('user_id').eq('id', eventId).single();
      if (event['user_id'] == currentUser.id) {
        updates['updated_at'] = DateTime.now().toIso8601String();
        await _supabase.from('events').update(updates).eq('id', eventId);
      }
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  // Delete event
  Future<void> deleteEvent(String eventId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Check if user owns the event
      final event = await _supabase.from('events').select('user_id').eq('id', eventId).single();
      if (event['user_id'] == currentUser.id) {
        await _supabase.from('events').delete().eq('id', eventId);
      }
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  // Search events
  Future<List<Map<String, dynamic>>> searchEvents(String searchQuery) async {
    if (searchQuery.isEmpty) {
      return await getEvents().first;
    }

    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%')
          .order('event_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching events: $e');
      return [];
    }
  }

  // Get user's events (created by user)
  Future<List<Map<String, dynamic>>> getUserEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('user_id', userId)
          .order('event_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user events: $e');
      return [];
    }
  }

  // Get events user is attending
  Future<List<Map<String, dynamic>>> getAttendingEvents(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .contains('attendees', [userId])
          .order('event_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting attending events: $e');
      return [];
    }
  }
}