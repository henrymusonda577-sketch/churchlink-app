import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create church icon
  await createChurchIcon();

  print('Church icons created successfully!');
  exit(0);
}

Future<void> createChurchIcon() async {
  // Create main church icon (1024x1024)
  final mainIcon = await createChurchIconWidget(1024);
  await saveIcon(mainIcon, 'assets/church_icon.png');

  // Create foreground icon for adaptive (1024x1024)
  final foregroundIcon =
      await createChurchIconWidget(1024, foregroundOnly: true);
  await saveIcon(foregroundIcon, 'assets/church_icon_foreground.png');
}

Future<Uint8List> createChurchIconWidget(int size,
    {bool foregroundOnly = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint();

  // Background (only if not foreground-only)
  if (!foregroundOnly) {
    paint.color = const Color(0xFF1E3A8A); // Church blue
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), paint);
  }

  // Church building
  final churchPaint = Paint()
    ..color = foregroundOnly ? const Color(0xFF1E3A8A) : Colors.white
    ..style = PaintingStyle.fill;

  final strokePaint = Paint()
    ..color = foregroundOnly ? const Color(0xFF1E3A8A) : Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.02;

  final center = size / 2;
  final buildingWidth = size * 0.6;
  final buildingHeight = size * 0.4;
  final buildingLeft = center - buildingWidth / 2;
  final buildingTop = center + size * 0.1;

  // Main church building
  canvas.drawRect(
    Rect.fromLTWH(buildingLeft, buildingTop, buildingWidth, buildingHeight),
    churchPaint,
  );

  // Church roof (triangle)
  final roofPath = Path();
  roofPath.moveTo(buildingLeft - size * 0.05, buildingTop);
  roofPath.lineTo(center, buildingTop - size * 0.15);
  roofPath.lineTo(buildingLeft + buildingWidth + size * 0.05, buildingTop);
  roofPath.close();
  canvas.drawPath(roofPath, churchPaint);

  // Cross on top
  final crossSize = size * 0.08;
  final crossTop = buildingTop - size * 0.25;

  // Vertical part of cross
  canvas.drawRect(
    Rect.fromLTWH(
        center - crossSize * 0.15, crossTop, crossSize * 0.3, crossSize * 1.2),
    churchPaint,
  );

  // Horizontal part of cross
  canvas.drawRect(
    Rect.fromLTWH(center - crossSize * 0.4, crossTop + crossSize * 0.2,
        crossSize * 0.8, crossSize * 0.3),
    churchPaint,
  );

  // Church door
  final doorWidth = size * 0.12;
  final doorHeight = size * 0.2;
  final doorLeft = center - doorWidth / 2;
  final doorTop = buildingTop + buildingHeight - doorHeight;

  if (foregroundOnly) {
    canvas.drawRect(
      Rect.fromLTWH(doorLeft, doorTop, doorWidth, doorHeight),
      Paint()..color = Colors.white,
    );
  } else {
    canvas.drawRect(
      Rect.fromLTWH(doorLeft, doorTop, doorWidth, doorHeight),
      Paint()..color = const Color(0xFF1E3A8A),
    );
  }

  // Church windows
  final windowSize = size * 0.06;
  final windowY = buildingTop + size * 0.08;

  // Left window
  final leftWindowPaint = Paint()
    ..color = foregroundOnly ? Colors.white : const Color(0xFF1E3A8A);
  canvas.drawRect(
    Rect.fromLTWH(buildingLeft + size * 0.08, windowY, windowSize, windowSize),
    leftWindowPaint,
  );

  // Right window
  final rightWindowPaint = Paint()
    ..color = foregroundOnly ? Colors.white : const Color(0xFF1E3A8A);
  canvas.drawRect(
    Rect.fromLTWH(buildingLeft + buildingWidth - size * 0.08 - windowSize,
        windowY, windowSize, windowSize),
    rightWindowPaint,
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  return byteData!.buffer.asUint8List();
}

Future<void> saveIcon(Uint8List bytes, String path) async {
  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);
}
