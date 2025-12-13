import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/pastor_dashboard.dart';

void main() {
  testWidgets('PastorDashboard renders without error', (WidgetTester tester) async {
    // Mock user info
    final userInfo = {'name': 'Test Pastor', 'id': '123', 'email': 'pastor@test.com'};

    // Build the widget
    await tester.pumpWidget(
      MaterialApp(
        home: PastorDashboard(userInfo: userInfo),
      ),
    );

    // Wait for async operations
    await tester.pumpAndSettle();

    // Check if the app bar title is present
    expect(find.text('Pastor Dashboard'), findsOneWidget);

    // Check if loading indicator appears initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}