import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class HandOverlayPainter extends CustomPainter {
  final List<List<Landmark>> landmarksByHand;
  final Size imageSize;
  final bool isFrontCamera;
  final int frameRotationDegrees;
  final bool mirrorFrontCamera;

  static const List<(int, int)> _connections = [
    (0,1),(1,2),(2,3),(3,4),
    (0,5),(5,6),(6,7),(7,8),
    (0,9),(9,10),(10,11),(11,12),
    (0,13),(13,14),(14,15),(15,16),
    (0,17),(17,18),(18,19),(19,20),
    (5,9),(9,13),(13,17),
  ];

  HandOverlayPainter({
    required this.landmarksByHand,
    required this.imageSize,
    this.isFrontCamera = true,
    this.frameRotationDegrees = 0,
    this.mirrorFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarksByHand.isEmpty) return;

    Offset toOffset(Landmark lm) {
      double x = lm.x;
      double y = lm.y;

      // Hand landmarks are normalized in sensor space; rotate into preview space.
      // Use the opposite 90deg direction mapping to match the camera preview.
      switch (frameRotationDegrees % 360) {
        case 90:
          final nx = 1.0 - y;
          final ny = x;
          x = nx;
          y = ny;
          break;
        case 180:
          x = 1.0 - x;
          y = 1.0 - y;
          break;
        case 270:
          final nx = y;
          final ny = 1.0 - x;
          x = nx;
          y = ny;
          break;
      }

      if (isFrontCamera && mirrorFrontCamera) {
        x = 1.0 - x;
      }

      return Offset(x * size.width, y * size.height);
    }

    final bone = Paint()
      ..color = const Color(0x9922D3A0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dot = Paint()
      ..color = const Color(0xFF22D3A0)
      ..style = PaintingStyle.fill;

    final dotBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final landmarks in landmarksByHand) {
      if (landmarks.length < 21) continue;
      for (final (a, b) in _connections) {
        canvas.drawLine(toOffset(landmarks[a]), toOffset(landmarks[b]), bone);
      }
      for (final lm in landmarks) {
        final pt = toOffset(lm);
        canvas.drawCircle(pt, 4, dot);
        canvas.drawCircle(pt, 4, dotBorder);
      }
    }
  }

  @override
  bool shouldRepaint(HandOverlayPainter old) =>
      old.landmarksByHand != landmarksByHand;
}
