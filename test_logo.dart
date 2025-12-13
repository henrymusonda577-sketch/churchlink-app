import 'package:flutter/material.dart';
import 'package:my_flutter_app/logo_widget.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Logo Test')),
        body: Center(
          child: LogoWidget(
            size: 200, // Use the enhanced size
            withAnimation: true, // Enable animation
            withShadow: true, // Enable shadow
            withGlow: true, // Enable glow effect
          ),
        ),
      ),
    );
  }
}
