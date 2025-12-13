import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_flutter_app/chat_screen.dart';
import 'package:my_flutter_app/services/call_manager.dart';
import 'package:my_flutter_app/services/user_service.dart';
import 'package:my_flutter_app/widgets/call_screen.dart';

void main() {
  group('Call Integration Tests', () {
    testWidgets('ChatScreen renders without errors',
        (WidgetTester tester) async {
      // Build the widget with minimal setup
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CallManager>(
              create: (_) => CallManager(),
            ),
            Provider<UserService>(
              create: (_) => UserService(),
            ),
          ],
          child: const MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify basic UI elements are present
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Video Calls'), findsOneWidget);
    });

    testWidgets('ChatScreen has call manager initialized',
        (WidgetTester tester) async {
      CallManager? capturedCallManager;

      // Build the widget
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CallManager>(
              create: (context) {
                capturedCallManager = CallManager();
                return capturedCallManager!;
              },
            ),
            Provider<UserService>(
              create: (_) => UserService(),
            ),
          ],
          child: const MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify CallManager was created
      expect(capturedCallManager, isNotNull);
    });

    testWidgets('Call buttons are present in UI structure',
        (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CallManager>(
              create: (_) => CallManager(),
            ),
            Provider<UserService>(
              create: (_) => UserService(),
            ),
          ],
          child: const MaterialApp(
            home: ChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the basic structure is there
      expect(find.byType(TabBarView), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('CallManager can be instantiated', (WidgetTester tester) async {
      final callManager = CallManager();

      // Verify CallManager has expected initial state
      expect(callManager.currentCallState, equals(CallState.idle));
      expect(callManager.currentCall, isNull);

      // Clean up
      callManager.dispose();
    });

    testWidgets('CallScreen widget can be instantiated',
        (WidgetTester tester) async {
      // Test that CallScreen can be created with required parameters
      const callScreen = CallScreen(
        callId: 'test-call-id',
        isIncoming: false,
        otherUserId: 'test-user-id',
        otherUserName: 'Test User',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: callScreen,
        ),
      );

      // Verify the widget renders
      expect(find.byType(CallScreen), findsOneWidget);
    });
  });
}
